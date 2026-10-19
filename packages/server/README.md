# ConfigCat OpenFeature Server Provider for Dart

[![pub package](https://img.shields.io/pub/v/configcat_openfeature_server_provider.svg)](https://pub.dev/packages/configcat_openfeature_server_provider)
[![Dart server provider CI](https://github.com/configcat/openfeature-dart/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/configcat/openfeature-dart/actions/workflows/test.yml)

This repository contains an OpenFeature provider that allows [ConfigCat](https://configcat.com) to be used with
the [OpenFeature Dart Server SDK](https://github.com/open-feature/dart-sdk/tree/main/packages/openfeature_dart_server_sdk).

## Installation

```yaml
dependencies:
  configcat_openfeature_server_provider: ^0.1.0
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
  await OpenFeatureAPI().setProviderAndWait(provider);

  // Create a client.
  final client = OpenFeatureAPI().getClient('my-app');
  
  // Configure the evaluation context.
  final ctx = EvaluationContext(attributes: {'targetingKey': '<UNIQUE-USER-IDENTIFIER>'});
  
  // Evaluate feature flag.
  final isAwesomeFeatureEnabled = await client.getBooleanFlag(
    'isAwesomeFeatureEnabled',
    defaultValue: false,
    context: ctx,
  );
}
```

For more information about all the configuration options, see
the [Dart SDK documentation](https://configcat.com/docs/sdk-reference/dart/#setting-up-the-configcat-client).

## Need help?

https://configcat.com/support

## Contributing

Contributions are welcome. For more info please read the [Contribution Guideline](../../CONTRIBUTING.md).

## About ConfigCat

ConfigCat is a feature flag and configuration management service that lets you separate releases from deployments. You
can turn your features ON/OFF using <a href="https://app.configcat.com" target="_blank">ConfigCat Dashboard</a> even
after they are deployed. ConfigCat lets you target specific groups of users based on region, email or any other custom
user attribute.

ConfigCat is a <a href="https://configcat.com" target="_blank">hosted feature flag service</a>. Manage feature toggles
across frontend, backend, mobile, desktop apps. <a href="https://configcat.com" target="_blank">Alternative to
LaunchDarkly</a>. Management app + feature flag SDKs.

- [Official ConfigCat OpenFeature Providers](https://configcat.com/docs/sdk-reference/openfeature)
- [Official ConfigCat SDKs](https://configcat.com/docs/sdk-reference/overview)
- [Documentation](https://configcat.com/docs)
- [Blog](https://configcat.com/blog)