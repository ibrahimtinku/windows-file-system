import 'dart:ffi';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../services/config_service.dart';


const _INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF;
const _FILE_ATTRIBUTE_READONLY = 0x1;

class FolderManager {
  static const String logFileName = 'operations.log';
  static const String modelLogFileName = 'model_operations.log';
  final ConfigService configService = ConfigService();

  int Function(Pointer<Utf16>)? _getFileAttributes;
  int Function(Pointer<Utf16>, int)? _setFileAttributes;

  void _initializeWinAPI() {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    _getFileAttributes = kernel32.lookupFunction<
        Uint32 Function(Pointer<Utf16>),
        int Function(Pointer<Utf16>)
    >('GetFileAttributesW');

    _setFileAttributes = kernel32.lookupFunction<
        Int32 Function(Pointer<Utf16>, Uint32),
        int Function(Pointer<Utf16>, int)
    >('SetFileAttributesW');
  }

  Future<String> get appDataPath async {
    if (Platform.isWindows) {
      // Directly use the D: drive path for Windows
      return path.join(r'D:',  'SoftwareFile');
    }

    // Fallback to original behavior for other platforms
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, 'SoftwareFile');
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