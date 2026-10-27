import 'dart:async';
import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';

const _providerName = 'ConfigCat Server Provider';

/// ConfigCat OpenFeature provider.
///
/// Example:
/// ```dart
/// final provider = ConfigCatProvider(
///   sdkKey: '#YOUR-SDK-KEY#',
/// );
///
/// await OpenFeatureAPI().setProviderAndWait(provider);
///
/// final client = OpenFeatureAPI().getClient('my-app');
///
/// final isAwesomeFeatureEnabled = await client.getBooleanFlag(
///   'isAwesomeFeatureEnabled',
///   defaultValue: false,
/// );
/// ```
class ConfigCatProvider implements FeatureProvider {
  ProviderState _state = ProviderState.NOT_READY;
  Map<String, dynamic>? _initialContext;
  bool _initialized = false;
  late final ConfigCatClient _client;

  /// Creates a new [ConfigCatProvider].
  ///
  /// [sdkKey] - The SDK key.
  /// [options] - Configuration options for the underlying [ConfigCatClient].
  ConfigCatProvider({
    required String sdkKey,
    ConfigCatOptions options = ConfigCatOptions.defaultOptions,
  }) {
    final opts = options.copyWith(
      hooks: (Hooks hooks) {
        options.hooks?.call(hooks);
        hooks.addOnConfigChanged(
          (_, snapshot) => {
            if (snapshot.cacheState != ClientCacheState.noFlagData &&
                !_initialized)
              {_initialized = true, _state = ProviderState.READY},
          },
        );
      },
    );
    _client = ConfigCatClient.get(sdkKey: sdkKey, options: opts);
  }

  @override
  ProviderConfig get config => ProviderConfig();

  @override
  Future<void> connect() async {}

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) => _eval(flagKey, defaultValue, context);

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) => _eval(flagKey, defaultValue, context);

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) => _eval(flagKey, defaultValue, context);

  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final stringResult = await _eval(flagKey, '', context);
    if (stringResult.value.isEmpty) {
      return defaultValue.asErrorResult(
        flagKey,
        stringResult.errorMessage,
        stringResult.errorCode,
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(stringResult.value);
    } on FormatException {
      return defaultValue.asErrorResult(
        flagKey,
        'Value could not parsed as JSON: ${stringResult.value}',
        ErrorCode.PARSE_ERROR,
      );
    }
    if (decoded is! Map) {
      return defaultValue.asErrorResult(
        flagKey,
        'Parsed JSON is not a valid Map: ${stringResult.value}',
        ErrorCode.TYPE_MISMATCH,
      );
    }
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: Map<String, dynamic>.from(decoded),
      variant: stringResult.variant,
      evaluatedAt: DateTime.now(),
      evaluatorId: _providerName,
      errorCode: stringResult.errorCode,
      errorMessage: stringResult.errorMessage,
      reason: stringResult.reason,
    );
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) => _eval(flagKey, defaultValue, context);

  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    _initialContext = config;
    final state = await _client.waitForReady();
    if (state != ClientCacheState.noFlagData && !_initialized) {
      _initialized = true;
      _state = ProviderState.READY;
    }
  }

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: _providerName);

  @override
  String get name => metadata.name;

  @override
  Future<void> shutdown() async {
    _client.close();
    _state = ProviderState.SHUTDOWN;
  }

  @override
  ProviderState get state => _state;

  ConfigCatUser? _userFromContext(Map<String, dynamic>? context) {
    return {..._initialContext ?? {}, ...context ?? {}}.toUser();
  }

  @override
  Future<void> track(
    String trackingEventName, {
    Map<String, dynamic>? evaluationContext,
    TrackingEventDetails? trackingDetails,
  }) async {}

  Future<FlagEvaluationResult<T>> _eval<T>(
    String flagKey,
    T defaultValue,
    Map<String, dynamic>? context,
  ) async {
    final user = _userFromContext(context);
    final details = await _client.getValueDetails(
      key: flagKey,
      defaultValue: defaultValue,
      user: user,
    );
    return details.toEvalResult();
  }
}

extension ToEvalResult<T> on EvaluationDetails<T> {
  FlagEvaluationResult<T> toEvalResult() {
    return FlagEvaluationResult(
      flagKey: key,
      value: value,
      variant: variationId,
      evaluatedAt: DateTime.now(),
      evaluatorId: _providerName,
      errorCode: errorCode.toErrorCode(),
      errorMessage: error,
      reason: toReason(),
    );
  }
}

extension AsErrorResult<T> on T {
  FlagEvaluationResult<T> asErrorResult(
    String flagKey,
    String? errorMessage,
    ErrorCode? errorCode,
  ) {
    return FlagEvaluationResult(
      flagKey: flagKey,
      value: this,
      errorCode: errorCode,
      errorMessage: errorMessage,
      reason: 'ERROR',
      evaluatedAt: DateTime.now(),
      evaluatorId: _providerName,
    );
  }
}

extension ToErrorCode on EvaluationErrorCode {
  ErrorCode? toErrorCode() {
    switch (this) {
      case EvaluationErrorCode.none:
        return null;
      case EvaluationErrorCode.settingValueTypeMismatch:
        return ErrorCode.TYPE_MISMATCH;
      case EvaluationErrorCode.configJsonNotAvailable:
        return ErrorCode.PARSE_ERROR;
      case EvaluationErrorCode.settingKeyMissing:
        return ErrorCode.FLAG_NOT_FOUND;
      default:
        return ErrorCode.GENERAL;
    }
  }
}

extension ToReason<T> on EvaluationDetails<T> {
  String toReason() {
    if (errorCode != EvaluationErrorCode.none) {
      return 'ERROR';
    }
    if (matchedTargetingRule != null || matchedPercentageOption != null) {
      return 'TARGETING_MATCH';
    }
    return 'DEFAULT';
  }
}

extension ToUser on Map<String, dynamic> {
  ConfigCatUser? toUser() {
    if (length == 0) {
      return null;
    }
    var identifier = '';
    String? email;
    String? country;
    final custom = <String, Object>{};
    for (MapEntry<String, dynamic> entry in entries) {
      if (entry.key == 'Identifier' || entry.key == 'targetingKey') {
        identifier = entry.value;
      } else if (entry.key == 'Email' || entry.key == 'email') {
        email = entry.value;
      } else if (entry.key == 'Country' || entry.key == 'country') {
        country = entry.value;
      } else {
        custom[entry.key] = entry.value;
      }
    }
    return ConfigCatUser(
      identifier: identifier,
      email: email,
      country: country,
      custom: custom,
    );
  }
}

extension CopyWith on ConfigCatOptions {
  ConfigCatOptions copyWith({
    String? baseUrl,
    DataGovernance? dataGovernance,
    PollingMode? pollingMode,
    ConfigCatCache? cache,
    ConfigCatLogger? logger,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    FlagOverrides? override,
    ConfigCatUser? defaultUser,
    Function(Hooks)? hooks,
    bool? offline,
  }) => ConfigCatOptions(
    baseUrl: baseUrl ?? this.baseUrl,
    dataGovernance: dataGovernance ?? this.dataGovernance,
    pollingMode: pollingMode ?? this.pollingMode,
    cache: cache ?? this.cache,
    logger: logger ?? this.logger,
    httpClientAdapter: httpClientAdapter,
    connectTimeout: connectTimeout ?? this.connectTimeout,
    sendTimeout: sendTimeout ?? this.sendTimeout,
    receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    override: override ?? this.override,
    defaultUser: defaultUser ?? this.defaultUser,
    hooks: hooks ?? this.hooks,
    offline: offline ?? this.offline,
  );
}
