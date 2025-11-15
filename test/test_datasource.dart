import 'dart:convert';
import 'dart:io';

import 'package:configcat_client/configcat_client.dart';

class TestDatasource implements OverrideDataSource {
  @override
  Future<Map<String, Setting>> getOverrides() async {
    var jsonOverrideFile = await File(
      'test/data/test_json_complex.json',
    ).readAsString();
    final decoded = jsonDecode(jsonOverrideFile);
    final config = Config.fromJson(decoded);
    return config.entries;
  }
}
