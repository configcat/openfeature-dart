import 'dart:async';
import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

class ConfigCatProvider
    implements
        FeatureProvider,
        InitializableProvider,
        ContextReconciliationProvider,
        ProviderEventSource,
        ShutdownProvider {
  final StreamController<ProviderEvent> _events =
      StreamController<ProviderEvent>.broadcast(sync: true);
  bool _initialized = false;
  ConfigCatUser? _user;
  ConfigCatClientSnapshot? _snapshot;
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
        _snapshot = snapshot,
        if (snapshot.cacheState != ClientCacheState.noFlagData && !_initialized)
          {
            _initialized = true,
            _events.add(ProviderEvent(type: ProviderEventType.ready)),
          },
      },
    );
    final opts = options.copyWith(hooks: hooks);
    _client = ConfigCatClient.get(sdkKey: sdkKey, options: opts);
  }

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: 'ConfigCatProvider');

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) => _eval(flagKey, defaultValue, context);

  @override
  ResolutionDetails<double> resolveDoubleValue(
    String flagKey,
    double defaultValue,
    EvaluationContext context,
  ) => _eval(flagKey, defaultValue, context);

  @override
  ResolutionDetails<int> resolveIntegerValue(
    String flagKey,
    int defaultValue,
    EvaluationContext context,
  ) => _eval(flagKey, defaultValue, context);

  @override
  ResolutionDetails<String> resolveStringValue(
    String flagKey,
    String defaultValue,
    EvaluationContext context,
  ) => _eval(flagKey, defaultValue, context);

  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue,
    EvaluationContext context,
  ) {
    final stringResult = _eval(flagKey, '', context);
    if (stringResult.value.isEmpty) {
      return ResolutionDetails(
        value: defaultValue,
        reason: stringResult.reason,
        errorCode: stringResult.errorCode,
        errorMessage: stringResult.errorMessage,
      );
    }
    final decoded = jsonDecode(stringResult.value);
    if (decoded == null) {
      return ResolutionDetails(
        value: defaultValue,
        reason: 'ERROR',
        errorCode: ErrorCode.typeMismatch,
        errorMessage: 'Could not parse ${stringResult.value} as JSON',
      );
    }
    return ResolutionDetails(
      value: decoded,
      variant: stringResult.variant,
      errorCode: stringResult.errorCode,
      errorMessage: stringResult.errorMessage,
      reason: stringResult.reason,
    );
  }

  @override
  Stream<ProviderEvent> get events => _events.stream;

  @override
  Future<void> initialize(EvaluationContext context, {String? domain}) async {
    _user = context.toUser();
    final state = await _client.waitForReady();
    _snapshot = _client.snapshot();
    if (state != ClientCacheState.noFlagData && !_initialized) {
      _initialized = true;
      _events.add(ProviderEvent(type: ProviderEventType.ready));
    }
  }

  @override
  Future<void> onContextChanged(
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) {
    _user = newContext.toUser();
    final keys = _snapshot?.getAllKeys() ?? [];
    _events.add(
      ProviderEvent(type: ProviderEventType.contextChanged, flagsChanged: keys),
    );
    return Future.value();
  }

  @override
  Future<void> shutdown() async {
    _client.close();
    await _events.close();
  }

  ResolutionDetails<T> _eval<T>(
    String flagKey,
    T defaultValue,
    EvaluationContext context,
  ) {
    final snapshot = _snapshot ?? _client.snapshot();
    final user = _user ?? context.toUser();
    final details = snapshot.getValueDetails(
      key: flagKey,
      defaultValue: defaultValue,
      user: user,
    );
    return details.toResolutionDetails();
  }
}

extension ToUser on EvaluationContext {
  ConfigCatUser? toUser() {
    final custom = <String, Object>{};
    for (MapEntry<String, Object?> entry in attributes.entries) {
      final value = entry.value;
      if (value != null) {
        custom[entry.key] = value;
      }
    }
    return ConfigCatUser(
      identifier: targetingKey ?? '',
      email: getValue('Email')?.toString() ?? getValue('email')?.toString(),
      country:
          getValue('Country')?.toString() ?? getValue('country').toString(),
      custom: custom,
    );
  }
}

extension ToResolutionDetails<T> on EvaluationDetails<T> {
  ResolutionDetails<T> toResolutionDetails() {
    return ResolutionDetails(
      value: value,
      variant: variationId,
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
        return ErrorCode.typeMismatch;
      case EvaluationErrorCode.configJsonNotAvailable:
        return ErrorCode.parseError;
      case EvaluationErrorCode.settingKeyMissing:
        return ErrorCode.flagNotFound;
      default:
        return ErrorCode.general;
    }
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
