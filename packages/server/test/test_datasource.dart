import 'dart:convert';
import 'dart:io';

import 'package:configcat_client/configcat_client.dart';

class TestDatasource implements OverrideDataSource {
  @override
  Map<String, Setting> getOverrides() {
    var jsonOverrideFile = File(
      'test/data/test_json_complex.json',
    ).readAsStringSync();
    final decoded = jsonDecode(jsonOverrideFile);
    final config = Config.fromJson(decoded);
    return config.entries;
  }
}
