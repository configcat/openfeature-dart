# ConfigCat OpenFeature Client Provider for Dart

[![pub package](https://img.shields.io/pub/v/configcat_openfeature_client_provider.svg)](https://pub.dev/packages/configcat_openfeature_client_provider)
[![Dart client provider CI](https://github.com/configcat/openfeature-dart/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/configcat/openfeature-dart/actions/workflows/test.yml)

This repository contains an OpenFeature provider that allows [ConfigCat](https://configcat.com) to be used with
the [OpenFeature Dart Client SDK](https://github.com/open-feature/dart-sdk/tree/main/packages/openfeature_dart_client_sdk).

## Installation

```yaml
dependencies:
  configcat_openfeature_client_provider: ^0.1.0
```

## Usage

The constructor of `ConfigCatProvider` takes the SDK key and an optional `ConfigCatOptions`
argument containing the additional configuration options for
the [ConfigCat Dart SDK](https://github.com/configcat/dart-sdk):

```dart
import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_openfeature_client_provider/configcat_openfeature_client_provider.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

Future<void> main() async {
  // Configure the provider.
  final provider = ConfigCatProvider(
    sdkKey: '<YOUR-CONFIGCAT-SDK-KEY>',
    options: ConfigCatOptions(
      pollingMode: PollingMode.autoPoll(),
    ),
  );

  // Configure the OpenFeature API with the ConfigCat provider.
  await OpenFeatureAPI.instance.setProviderAndWait(provider);

  // Configure the evaluation context.
  await OpenFeatureAPI.instance.setEvaluationContextAndWait(
    EvaluationContext(targetingKey: '<UNIQUE-USER-IDENTIFIER>'),
  );

  // Create a client.
  final client = OpenFeatureAPI.instance.getClient();

  // Evaluate feature flag.
  final isAwesomeFeatureEnabled = client.getBooleanValue(
    'isAwesomeFeatureEnabled',
    false,
  );
}
```

For more information about all the configuration options, see
the [Dart SDK documentation](https://configcat.com/docs/sdk-reference/dart/#setting-up-the-configcat-client).
