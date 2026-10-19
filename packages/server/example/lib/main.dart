import 'dart:async';

import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_openfeature_server_provider/configcat_openfeature_server_provider.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';

Future<void> main() async {
  final provider = ConfigCatProvider(
    sdkKey: 'PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ',
    options: ConfigCatOptions(
      logger: ConfigCatLogger(
        // Info level logging helps to inspect the feature flag evaluation process.
        // Use the default Warning level to avoid too detailed logging in your application.
        level: LogLevel.info,
      ),
    ),
  );

  await OpenFeatureAPI().setProviderAndWait(provider);

  final client = OpenFeatureAPI().getClient('my-app');

  final isAwesomeFeatureEnabled = await client.getBooleanFlag(
    'isAwesomeFeatureEnabled',
    defaultValue: false,
  );

  print('isAwesomeFeatureEnabled: $isAwesomeFeatureEnabled');

  final ctx = EvaluationContext(attributes: {'Email': 'configcat@example.com'});

  final isPOCFeatureEnabled = await client.getBooleanFlag(
    'isPOCFeatureEnabled',
    defaultValue: false,
    context: ctx,
  );

  print('isPOCFeatureEnabled: $isPOCFeatureEnabled');

  await OpenFeatureAPI().shutdownProvider();
}
