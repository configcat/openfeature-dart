import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_openfeature_client_provider/configcat_openfeature_client_provider.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

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

  await OpenFeatureAPI.instance.setProviderAndWait(provider);

  final client = OpenFeatureAPI.instance.getClient();

  final isAwesomeFeatureEnabled = client.getBooleanValue(
    'isAwesomeFeatureEnabled',
    false,
  );

  print('isAwesomeFeatureEnabled: $isAwesomeFeatureEnabled');

  final ctx = EvaluationContext(attributes: {'Email': 'configcat@example.com'});
  await OpenFeatureAPI.instance.setEvaluationContextAndWait(ctx);

  final isPOCFeatureEnabled = client.getBooleanValue(
    'isPOCFeatureEnabled',
    false,
  );

  print('isPOCFeatureEnabled: $isPOCFeatureEnabled');

  await OpenFeatureAPI.instance.shutdown();
}
