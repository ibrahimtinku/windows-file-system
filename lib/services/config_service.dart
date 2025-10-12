import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:logger/logger.dart';

class ConfigService {
  final Logger logger = Logger();
  Map<String, dynamic>? _config;

  Future<Map<String, dynamic>> getConfig() async {
    if (_config != null) return _config!;

    try {
      final configFile = File(path.join(Directory.current.path, 'config.json'));
      if (!await configFile.exists()) {
        logger.e("Config file not found at ${configFile.path}");
        throw Exception("Config file not found");
      }

      final content = await configFile.readAsString();
      _config = json.decode(content);
      return _config!;
    } catch (e) {
      logger.e("Error loading config: $e");
      rethrow;
    }
  }

  Future<List<String>> getBrands() async {
    final config = await getConfig();
    return List<String>.from(config['brands']);
  }

  Future<List<String>> getModels(String brand) async {
    final config = await getConfig();
    return List<String>.from(config['${brand}-models'] ?? []);
  }
}