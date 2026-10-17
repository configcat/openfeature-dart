import 'dart:async';
import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';

const _providerName = 'ConfigCatProvider';

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
    final hooks = options.hooks ?? Hooks();
    hooks.addOnConfigChanged(
      (_, snapshot) => {
        if (snapshot.cacheState != ClientCacheState.noFlagData && !_initialized)
          {_initialized = true, _state = ProviderState.READY},
      },
    );
    final opts = options.copyWith(hooks: hooks);
    _client = ConfigCatClient.get(sdkKey: sdkKey, options: opts);
  }

  /// Gets the provider configuration.
  @override
  ProviderConfig get config => ProviderConfig();

  /// Connects to the provider. [ConfigCatProvider] doesn't implement this function.
  @override
  Future<void> connect() async {}

  /// Evaluates a boolean feature flag.
  ///
  /// [flagKey] - The feature flag key to evaluate.
  /// [defaultValue] - In case of any failure, this value will be returned.
  /// [context] - Evaluation context for targeting.
  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final user = _userFromContext(context);
    final details = await _client.getValueDetails(
      key: flagKey,
      defaultValue: defaultValue,
      user: user,
    );
    return details.toEvalResult();
  }

  /// Evaluates a double setting.
  ///
  /// [flagKey] - The setting key to evaluate.
  /// [defaultValue] - In case of any failure, this value will be returned.
  /// [context] - Evaluation context for targeting.
  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final user = _userFromContext(context);
    final details = await _client.getValueDetails(
      key: flagKey,
      defaultValue: defaultValue,
      user: user,
    );
    return details.toEvalResult();
  }

  /// Evaluates an integer setting.
  ///
  /// [flagKey] - The setting key to evaluate.
  /// [defaultValue] - In case of any failure, this value will be returned.
  /// [context] - Evaluation context for targeting.
  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final user = _userFromContext(context);
    final details = await _client.getValueDetails(
      key: flagKey,
      defaultValue: defaultValue,
      user: user,
    );
    return details.toEvalResult();
  }

  /// Evaluates an object setting.
  ///
  /// [flagKey] - The setting key to evaluate.
  /// [defaultValue] - In case of any failure, this value will be returned.
  /// [context] - Evaluation context for targeting.
  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final user = _userFromContext(context);
    final stringDetails = await _client.getValueDetails(
      key: flagKey,
      defaultValue: '',
      user: user,
    );
    if (stringDetails.value.isEmpty) {
      return Future.value(
        FlagEvaluationResult.error(
          flagKey,
          defaultValue,
          stringDetails.errorCode.toErrorCode() ?? ErrorCode.GENERAL,
          stringDetails.error ?? 'Evaluation failed.',
          evaluatorId: _providerName,
        ),
      );
    }
    final decoded = jsonDecode(stringDetails.value);
    return stringDetails.toEvalResultWithJsonValue(decoded);
  }

  /// Evaluates a string setting.
  ///
  /// [flagKey] - The setting key to evaluate.
  /// [defaultValue] - In case of any failure, this value will be returned.
  /// [context] - Evaluation context for targeting.
  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final user = _userFromContext(context);
    final details = await _client.getValueDetails(
      key: flagKey,
      defaultValue: defaultValue,
      user: user,
    );
    return details.toEvalResult();
  }

  /// Initializes the provider.
  ///
  /// [config] - Optional initialization context.
  @override
  Future<void> initialize([Map<String, dynamic>? config]) async {
    _initialContext = config;
    final state = await _client.waitForReady();
    if (state != ClientCacheState.noFlagData && !_initialized) {
      _initialized = true;
      _state = ProviderState.READY;
    }
  }

  /// Gets the provider metadata.
  @override
  ProviderMetadata get metadata => ProviderMetadata(name: _providerName);

  /// Gets the provider name.
  @override
  String get name => metadata.name;

  /// Shuts down the provider.
  @override
  Future<void> shutdown() async {
    _client.close();
    _state = ProviderState.SHUTDOWN;
  }

  /// Get the provider state.
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
      reason: error == null ? 'DEFAULT' : 'ERROR',
    );
  }
}

extension WithValueEvalResult<T, N extends Map<String, dynamic>>
    on EvaluationDetails<T> {
  FlagEvaluationResult<N> toEvalResultWithJsonValue(N val) {
    return FlagEvaluationResult(
      flagKey: key,
      value: val,
      variant: variationId,
      evaluatedAt: DateTime.now(),
      evaluatorId: _providerName,
      errorCode: errorCode.toErrorCode(),
      errorMessage: error,
      reason: error == null ? 'DEFAULT' : 'ERROR',
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
    Hooks? hooks,
    bool? offline,
  }) => ConfigCatOptions(
    baseUrl: baseUrl ?? this.baseUrl,
    dataGovernance: dataGovernance ?? this.dataGovernance,
    pollingMode: pollingMode ?? this.pollingMode,
    cache: cache ?? this.cache,
    logger: logger ?? this.logger,
    connectTimeout: connectTimeout ?? this.connectTimeout,
    sendTimeout: sendTimeout ?? this.sendTimeout,
    receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    override: override ?? this.override,
    defaultUser: defaultUser ?? this.defaultUser,
    hooks: hooks ?? this.hooks,
    offline: offline ?? this.offline,
  );
}
