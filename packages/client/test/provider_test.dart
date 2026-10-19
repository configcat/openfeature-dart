import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_openfeature_client_provider/configcat_openfeature_client_provider.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:test/test.dart';

import 'test_datasource.dart';

void main() {
  late OpenFeatureClient client;
  final api = OpenFeatureAPI.instance;
  final provider = ConfigCatProvider(
    sdkKey: 'localhost',
    options: ConfigCatOptions(
      override: FlagOverrides(
        dataSource: TestDatasource(),
        behaviour: OverrideBehaviour.localOnly,
      ),
    ),
  );

  setUpAll(() async {
    await api.setProviderAndWait(provider);
    client = api.getClient();
  });

  tearDownAll(() async {
    await api.shutdown();
  });

  group('metadata tests', () {
    test('name', () async {
      expect(client.providerMetadata.name, equals('ConfigCatProvider'));
    });

    test('state', () async {
      expect(client.providerStatus, ProviderStatus.ready);
    });
  });

  group('eval tests', () {
    test('bool', () {
      final result = client.getBooleanValue('enabledFeature', false);
      expect(result, isTrue);
    });
    test('int', () {
      final result = client.getIntegerValue('intSetting', 0);
      expect(result, equals(5));
    });
    test('double', () {
      final result = client.getDoubleValue('doubleSetting', 0.0);
      expect(result, equals(1.2));
    });
    test('string', () {
      final result = client.getStringValue('stringSetting', '');
      expect(result, equals('test'));
    });
    test('object', () {
      final result = client.getStructureValue('objectSetting', {});
      expect(result['bool_field'], isTrue);
      expect(result['text_field'], equals('value'));
    });
  });

  group('targeting tests', () {
    test('user', () {
      final time = DateTime.parse('2025-05-30T10:15:30.00Z');
      final ctx = EvaluationContext(
        targetingKey: '1234',
        attributes: {
          'email': 'example@configcat.com',
          'country': 'HU',
          'time': time,
          'custom1': 4,
          'custom2': true,
          'custom3': 1.2,
        },
      );

      final user = ctx.toUser()!;
      expect(user.identifier, equals('1234'));
      expect(user.getAttribute('Email'), equals('example@configcat.com'));
      expect(user.getAttribute('Country'), equals('HU'));
      expect(user.getAttribute('time'), equals(time));
      expect(user.getAttribute('custom1'), equals(4));
      expect(user.getAttribute('custom2'), equals(true));
      expect(user.getAttribute('custom3'), equals(1.2));
    });

    test('eval with user', () async {
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'example@matching.com'),
      );

      final result = client.getBooleanValue('disabledFeature', false);
      expect(result, isTrue);

      await api.setEvaluationContextAndWait(
        EvaluationContext(
          targetingKey: 'example@matching.com',
          attributes: {'custom-anything': 'something'},
        ),
      );
      final customResult = client.getBooleanValue('disabledFeature', false);
      expect(customResult, isTrue);
    });
  });

  group('details tests', () {
    test('bool', () {
      final result = client.getBooleanDetails('enabledFeature', false);
      expect(result.value, isTrue);
      expect(result.variant, 'v-enabled');
      expect(result.reason, 'DEFAULT');
    });
    test('int', () {
      final result = client.getIntegerDetails('intSetting', 0);
      expect(result.value, equals(5));
      expect(result.variant, 'v-int');
      expect(result.reason, 'DEFAULT');
    });
    test('double', () {
      final result = client.getDoubleDetails('doubleSetting', 0.0);
      expect(result.value, equals(1.2));
      expect(result.variant, 'v-double');
      expect(result.reason, 'DEFAULT');
    });
    test('string', () {
      final result = client.getStringDetails('stringSetting', '');
      expect(result.value, equals('test'));
      expect(result.variant, 'v-string');
      expect(result.reason, 'DEFAULT');
    });
    test('object', () {
      final result = client.getStructureDetails('objectSetting', {});
      expect(result.value['bool_field'], isTrue);
      expect(result.value['text_field'], equals('value'));
      expect(result.variant, 'v-object');
      expect(result.reason, 'DEFAULT');
    });

    test('errors', () {
      final result = client.getBooleanDetails('non-existing', false);
      expect(result.value, isFalse);
      expect(result.errorCode, equals(ErrorCode.flagNotFound));
      expect(result.reason, 'ERROR');
      expect(
        result.errorMessage,
        contains(
          'Failed to evaluate setting \'non-existing\' (the key was not found in config JSON)',
        ),
      );

      final stringResult = client.getBooleanDetails('stringSetting', false);
      expect(stringResult.value, isFalse);
      expect(stringResult.errorCode, equals(ErrorCode.typeMismatch));
      expect(stringResult.reason, 'ERROR');
      expect(
        stringResult.errorMessage,
        contains(
          'The type of a setting must match the type of the specified default value',
        ),
      );
    });
  });

  group('integ tests', () {
    test('valid', () async {
      final provider = ConfigCatProvider(
        sdkKey: 'PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ',
      );
      await provider.initialize(EvaluationContext());

      final result = provider.resolveBooleanValue(
        'isAwesomeFeatureEnabled',
        false,
        EvaluationContext(),
      );
      expect(result.value, isTrue);
    });
  });
}
