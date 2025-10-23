import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../services/config_service.dart';


class FolderManager {
  static const String logFileName = 'operations.log';
  static const String modelLogFileName = 'model_operations.log';
  final ConfigService configService = ConfigService();
  String? _appDataPath;


  Future<String> get appDataPath async {
    if (_appDataPath == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _appDataPath = path.join(appDir.path, 'SecureFileManager');
    }
    return _appDataPath!;
  }

  Future<List<String>> getBrands() async {
    return await configService.getBrands();
  }

  Future<void> initializeAppFolders() async {
    final baseDir = await appDataPath;
    final brands = await getBrands();

    for (final brand in brands) {
      final brandDir = Directory(path.join(baseDir, brand));
      await brandDir.create(recursive: true);

      // Create brand-level log
      final brandLog = File(path.join(brandDir.path, logFileName));
      if (!await brandLog.exists()) {
        await brandLog.writeAsString('[$brand] Initialized ${DateTime.now()}\n');
      }
    }
  }

  Future<void> createModelFolder(String brand, String modelName) async {
    final baseDir = await appDataPath;
    final modelDir = Directory(path.join(baseDir, brand, modelName));
    await modelDir.create(recursive: true);

    // Create model-level log
    final modelLog = File(path.join(modelDir.path, modelLogFileName));
    if (!await modelLog.exists()) {
      await modelLog.writeAsString('[$modelName] Initialized ${DateTime.now()}\n');
    }
  }

  Future<List<String>> getModels(String brand) async {
    final baseDir = await appDataPath;
    final brandDir = Directory(path.join(baseDir, brand));
    if (await brandDir.exists()) {
      return brandDir.list()
          .where((entity) => entity is Directory)
          .map((dir) => path.basename(dir.path))
          .toList();
    }
    return [];
  }

  Future<String> getModelPath(String brand, String model) async {
    final baseDir = await appDataPath;
    return path.join(baseDir, brand, model);
  }

  Future<String> getBrandPath(String brand) async {
    final baseDir = await appDataPath;
    return path.join(baseDir, brand);
  }

  Future<File> getBrandLogFile(String brand) async {
    final brandPath = await getBrandPath(brand);
    return File(path.join(brandPath, logFileName));
  }

  Future<String?> selectBackupLocation() async {
    if (Platform.isWindows) {
      final result = await FilePicker.platform.getDirectoryPath();
      return result;
    }
    return null;
  }
}