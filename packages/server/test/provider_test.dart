import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_openfeature_server_provider/configcat_openfeature_server_provider.dart';
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';
import 'package:test/test.dart';

import 'test_datasource.dart';

void main() {
  late FeatureClient client;
  final api = OpenFeatureAPI();
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
    client = api.getClient('default');
  });

  tearDownAll(() async {
    await api.shutdownProvider();
  });

  group('metadata tests', () {
    test('name', () async {
      expect(client.provider.name, equals('ConfigCatProvider'));
      expect(client.provider.metadata.name, client.provider.name);
    });

    test('state', () async {
      expect(client.provider.state, ProviderState.READY);
    });
  });

  group('eval tests', () {
    test('bool', () async {
      final result = await client.getBooleanFlag(
        'enabledFeature',
        defaultValue: false,
      );
      expect(result, isTrue);
    });
    test('int', () async {
      final result = await client.getIntegerFlag('intSetting', defaultValue: 0);
      expect(result, equals(5));
    });
    test('double', () async {
      final result = await client.getDoubleFlag(
        'doubleSetting',
        defaultValue: 0.0,
      );
      expect(result, equals(1.2));
    });
    test('string', () async {
      final result = await client.getStringFlag(
        'stringSetting',
        defaultValue: '',
      );
      expect(result, equals('test'));
    });
    test('object', () async {
      final result = await client.getObjectFlag(
        'objectSetting',
        defaultValue: {},
      );
      expect(result['bool_field'], isTrue);
      expect(result['text_field'], equals('value'));
    });
  });

  group('targeting tests', () {
    test('user', () {
      final time = DateTime.parse('2025-05-30T10:15:30.00Z');
      final ctx = EvaluationContext(
        attributes: {
          'targetingKey': '1234',
          'email': 'example@configcat.com',
          'country': 'HU',
          'time': time,
          'custom1': 4,
          'custom2': true,
          'custom3': 1.2,
        },
      );

      final user = ctx.attributes.toUser()!;
      expect(user.identifier, equals('1234'));
      expect(user.getAttribute('Email'), equals('example@configcat.com'));
      expect(user.getAttribute('Country'), equals('HU'));
      expect(user.getAttribute('time'), equals(time));
      expect(user.getAttribute('custom1'), equals(4));
      expect(user.getAttribute('custom2'), equals(true));
      expect(user.getAttribute('custom3'), equals(1.2));
    });

    test('eval with user', () async {
      final ctx = EvaluationContext(
        attributes: {'targetingKey': 'example@matching.com'},
      );

      final result = await client.getBooleanFlag(
        'disabledFeature',
        defaultValue: false,
        context: ctx,
      );
      expect(result, isTrue);

      final customCtx = EvaluationContext(
        attributes: {
          'targetingKey': 'example@matching.com',
          'custom-anything': 'something',
        },
      );

      final customResult = await client.getBooleanFlag(
        'disabledFeature',
        defaultValue: false,
        context: customCtx,
      );
      expect(customResult, isTrue);
    });
  });

  group('details tests', () {
    test('bool', () async {
      final result = await client.getBooleanEvaluationDetails(
        'enabledFeature',
        defaultValue: false,
      );
      expect(result.value, isTrue);
      expect(result.variant, 'v-enabled');
      expect(result.reason, 'DEFAULT');
    });
    test('int', () async {
      final result = await client.getIntegerEvaluationDetails(
        'intSetting',
        defaultValue: 0,
      );
      expect(result.value, equals(5));
      expect(result.variant, 'v-int');
      expect(result.reason, 'DEFAULT');
    });
    test('double', () async {
      final result = await client.getDoubleEvaluationDetails(
        'doubleSetting',
        defaultValue: 0.0,
      );
      expect(result.value, equals(1.2));
      expect(result.variant, 'v-double');
      expect(result.reason, 'DEFAULT');
    });
    test('string', () async {
      final result = await client.getStringEvaluationDetails(
        'stringSetting',
        defaultValue: '',
      );
      expect(result.value, equals('test'));
      expect(result.variant, 'v-string');
      expect(result.reason, 'DEFAULT');
    });
    test('object', () async {
      final result = await client.getObjectEvaluationDetails(
        'objectSetting',
        defaultValue: {},
      );
      expect(result.value['bool_field'], isTrue);
      expect(result.value['text_field'], equals('value'));
      expect(result.variant, 'v-object');
      expect(result.reason, 'DEFAULT');
    });

    test('errors', () async {
      final result = await client.provider.getBooleanFlag(
        'non-existing',
        false,
      );
      expect(result.value, isFalse);
      expect(result.errorCode, equals(ErrorCode.FLAG_NOT_FOUND));
      expect(result.reason, 'ERROR');
      expect(
        result.errorMessage,
        contains(
          'Failed to evaluate setting \'non-existing\' (the key was not found in config JSON)',
        ),
      );

      final stringResult = await client.provider.getBooleanFlag(
        'stringSetting',
        false,
      );
      expect(stringResult.value, isFalse);
      expect(stringResult.errorCode, equals(ErrorCode.TYPE_MISMATCH));
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
      await provider.initialize();

      final result = await provider.getBooleanFlag(
        'isAwesomeFeatureEnabled',
        false,
      );
      expect(result.value, isTrue);
    });
  });
}
