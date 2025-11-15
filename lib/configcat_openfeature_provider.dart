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
/// await OpenFeatureAPI().setProvider(provider);
///
/// final client = FeatureClient(
///   metadata: ClientMetadata(name: "my-app"),
///   hookManager: HookManager(),
///   defaultContext: EvaluationContext(attributes: {}),
///   provider: OpenFeatureAPI().provider,
/// );
///
/// final isAwesomeFeatureEnabled = await client.getBooleanFlag(
///   'isAwesomeFeatureEnabled',
///   defaultValue: false,
/// );
/// ```
class ConfigCatProvider implements FeatureProvider {
  ProviderState _state = ProviderState.NOT_READY;
  Map<String, dynamic>? _initialContext;
  late final ConfigCatClient _client;
  final Completer<void> _completer = Completer();

  /// Creates a new [ConfigCatProvider].
  ///
  /// [sdkKey] - The SDK key.
  /// [options] - Configuration options for the underlying [ConfigCatClient].
  ConfigCatProvider({
    required String sdkKey,
    ConfigCatOptions options = ConfigCatOptions.defaultOptions,
  }) {
    if (options.override?.behaviour == OverrideBehaviour.localOnly) {
      _completer.complete();
    }
    final opts = options.copyWithHooks(
      () => {
        if (!_completer.isCompleted) {_completer.complete()},
      },
      (msg, [err, tr]) => {
        if (!_completer.isCompleted)
          {
            _completer.completeError(
              err ?? 'Provider initialization failed. $msg',
              tr,
            ),
          },
      },
    );
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
          stringDetails.error?.toErrorCode() ?? ErrorCode.GENERAL,
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
    try {
      if (!_completer.isCompleted) {
        await _completer.future;
      }
      _initialContext = config;
      _state = ProviderState.READY;
    } catch (error) {
      _state = ProviderState.ERROR;
      rethrow;
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
}

extension _Copy on ConfigCatOptions {
  ConfigCatOptions copyWithHooks(
    Function() onClientReady,
    Function(String, [dynamic error, StackTrace? stackTrace]) onError,
  ) {
    var newHooks = hooks;
    if (newHooks == null) {
      newHooks = Hooks(onClientReady: onClientReady, onError: onError);
    } else {
      newHooks.addOnClientReady(onClientReady);
      newHooks.addOnError(onError);
    }
    return ConfigCatOptions(
      hooks: newHooks,
      baseUrl: baseUrl,
      dataGovernance: dataGovernance,
      pollingMode: pollingMode,
      cache: cache,
      logger: logger,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      httpClientAdapter: httpClientAdapter,
      override: this.override,
      defaultUser: defaultUser,
      offline: offline,
    );
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

extension _ToEvalResult<T> on EvaluationDetails<T> {
  FlagEvaluationResult<T> toEvalResult() {
    return FlagEvaluationResult(
      flagKey: key,
      value: value,
      variant: variationId,
      evaluatedAt: DateTime.now(),
      evaluatorId: _providerName,
      errorCode: error?.toErrorCode(),
      errorMessage: error,
      reason: error == null ? 'DEFAULT' : 'ERROR',
    );
  }
}

extension _WithValueEvalResult<T, N extends Map<String, dynamic>>
    on EvaluationDetails<T> {
  FlagEvaluationResult<N> toEvalResultWithJsonValue(N val) {
    return FlagEvaluationResult(
      flagKey: key,
      value: val,
      variant: variationId,
      evaluatedAt: DateTime.now(),
      evaluatorId: _providerName,
      errorCode: error?.toErrorCode(),
      errorMessage: error,
      reason: error == null ? 'DEFAULT' : 'ERROR',
    );
  }
}

extension _ToErrorCode on String {
  ErrorCode toErrorCode() {
    if (contains('the key was not found in config JSON')) {
      return ErrorCode.FLAG_NOT_FOUND;
    } else if (contains('Config JSON is not present')) {
      return ErrorCode.PARSE_ERROR;
    } else if (contains('Setting type is invalid') ||
        contains('type of a setting must match the type')) {
      return ErrorCode.TYPE_MISMATCH;
    } else {
      return ErrorCode.GENERAL;
    }
  }
}
