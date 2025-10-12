import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:logger/logger.dart';
import 'package:hashlib/hashlib.dart';
import '../utils/folder_manager.dart';

class FileService {
  final FolderManager folderManager = FolderManager();
  final Logger logger = Logger();

  Future<bool> _canAccessFile(File file) async {
    try {
      await file.length();
      final stream = await file.open(mode: FileMode.read);
      await stream.close();
      return true;
    } catch (e) {
      logger.w('File ${file.path} is not accessible: $e');
      return false;
    }
  }

  Future<String> generateCRC32(File file) async {
    try {

      // Read entire file and compute CRC32
      final bytes = await file.readAsBytes();
      final hash = crc32.convert(bytes);

      return hash.hex().toUpperCase();
    } catch (e) {
      logger.e('Failed to generate CRC32 for ${file.path}: $e');
      throw Exception('Failed to generate CRC32: $e');
    }
  }

  Future<void> _logOperation(String brand, String model, String entry, {String? customBaseDir}) async {
    final baseDir = customBaseDir ?? await folderManager.appDataPath;
    final logDir = Directory(path.join(baseDir, brand, model));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true); // Ensure the directory exists
    }
    final logFile = File(path.join(logDir.path, 'model_log.txt'));
    try {
      await logFile.writeAsString('$entry\n', mode: FileMode.append, flush: true);
    } catch (e) {
      logger.e('Error writing to log file ${logFile.path}: $e');
      rethrow;
    }
  }

  Future<void> updateSoftwareHashes(String brand, String model, String fileName, String hash, {bool remove = false}) async {
    final modelPath = await folderManager.getModelPath(brand, model);
    final hashesFile = File(path.join(modelPath, 'software_hashes.json'));
    Map<String, dynamic> hashes = {};

    if (await hashesFile.exists()) {
      try {
        final content = await hashesFile.readAsString();
        hashes = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        logger.w('Failed to read software_hashes.json: $e, starting fresh');
        hashes = {};
      }
    }

    if (remove) {
      hashes.remove(fileName);
      logger.i('Removed $fileName from software_hashes.json for $brand-$model');
    } else {
      hashes[fileName] = hash;
      logger.i('Updated software_hashes.json for $brand-$model: $fileName -> $hash');
    }

    try {
      await hashesFile.writeAsString(jsonEncode(hashes), flush: true);
      if (hashes.isEmpty && await hashesFile.exists()) {
        await hashesFile.delete();
        logger.i('Deleted empty software_hashes.json for $brand-$model');
      }
    } catch (e) {
      logger.e('Failed to write software_hashes.json for $brand-$model: $e');
      throw Exception('Failed to update software_hashes.json: $e');
    }
  }

  Future<void> copyFileToLocation({
    required String sourcePath,
    required String fileName,
    required String brand,
    required String model,
    required String destinationPath,
    Map<String, Map<String, String>>? softwareHashes,
  }) async {
    logger.i('Starting copy operation: $sourcePath to $destinationPath');
    final sourceFile = File(sourcePath);
    final sourceDir = Directory(sourcePath);
    final destPath = path.join(destinationPath, brand, model);

    if (await sourceDir.exists()) {
      final destDir = Directory(path.join(destPath, fileName));
      try {
        if (!await destDir.parent.exists()) {
          await destDir.parent.create(recursive: true);
        }
        if (await destDir.exists()) {
          await destDir.delete(recursive: true);
        }
        // Check hashes for all files in the directory
        if (softwareHashes != null) {
          final key = "$brand-$model";
          if (softwareHashes.containsKey(key)) {
            await for (var entity in sourceDir.list(recursive: true)) {
              if (entity is File) {
                final fileName = path.basename(entity.path);
                if (softwareHashes[key]!.containsKey(fileName)) {
                  final computedHash = await generateCRC32(entity);
                  final expectedHash = softwareHashes[key]![fileName]!;
                  if (computedHash != expectedHash) {
                    throw Exception('File does not match: hash mismatch for $fileName');
                  }
                }
              }
            }
          }
        }
        await copyDirectory(sourceDir, destDir, customBaseDir: destinationPath);
        final logEntry = 'COPY DIRECTORY: $fileName to $destPath at ${DateTime.now()}';
        await _logOperation(brand, model, logEntry, customBaseDir: destinationPath);
        logger.i('Directory copy completed: ${destDir.path}');
      } catch (e) {
        logger.e('Directory copy failed for $fileName: $e');
        if (await destDir.exists()) {
          await destDir.delete(recursive: true);
        }
        rethrow;
      }
      return;
    }

    if (await sourceFile.exists()) {
      final destFile = File(path.join(destPath, fileName));
      if (!await _canAccessFile(sourceFile)) {
        logger.e('Source file is not accessible: ${sourceFile.path}');
        throw Exception('Source file is not accessible: ${sourceFile.path}');
      }
      // Perform SHA-1 hash check if softwareHashes provided
      if (softwareHashes != null) {
        final key = "$brand-$model";
        if (softwareHashes.containsKey(key) && softwareHashes[key]!.containsKey(fileName)) {
          final computedHash = await generateCRC32(sourceFile);
          final expectedHash = softwareHashes[key]![fileName]!;
          if (computedHash != expectedHash) {
            throw Exception('File does not match: hash mismatch for $fileName');
          }
        }
      }
      try {
        if (!await Directory(destPath).exists()) {
          await Directory(destPath).create(recursive: true);
        }
        if (await destFile.exists()) {
          await destFile.delete();
        }
        final crc32 = await generateCRC32(sourceFile);
        await sourceFile.copy(destFile.path);
        await updateSoftwareHashes(brand, model, fileName, crc32);
        final logEntry = 'COPY FILE: $fileName to $destPath (CRC32: $crc32) at ${DateTime.now()}';
        logger.i('Attempting to log: $logEntry'); // Debug log
        await _logOperation(brand, model, logEntry, customBaseDir: destinationPath);
        logger.i('Log written to ${path.join(destinationPath, brand, model, 'model_log.txt')}'); // Debug log using destinationPath
        logger.i('File copy completed: ${destFile.path}');
      } catch (e) {
        logger.e('File copy failed for $fileName: $e');
        if (await destFile.exists()) {
          await destFile.delete();
        }
        rethrow;
      }
      return;
    }

    logger.e('Source does not exist: $sourcePath');
    throw Exception('Source does not exist: $sourcePath');
  }

  Future<void> copyDirectory(Directory source, Directory destination, {String? customBaseDir}) async {
    logger.i('Starting directory copy: ${source.path} to ${destination.path}');
    if (!await source.exists()) {
      logger.e('Source directory does not exist: ${source.path}');
      throw Exception('Source directory does not exist: ${source.path}');
    }
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    try {
      await for (var entity in source.list(recursive: false)) {
        final entityName = path.basename(entity.path);
        final newPath = path.join(destination.path, entityName);
        if (entity is File) {
          if (!await _canAccessFile(entity)) {
            logger.e('File is not accessible: ${entity.path}');
            throw Exception('File is not accessible: ${entity.path}');
          }
          final destFile = File(newPath);
          if (await destFile.exists()) {
            await destFile.delete();
          }
          final crc32 = await generateCRC32(entity);
          await entity.copy(newPath);
          // Log CRC32 for each file in the directory
          final logEntry = 'COPY FILE: $entityName to $newPath (CRC32: $crc32) at ${DateTime.now()}';
          // Extract brand and model from destination path (assuming path structure: .../brand/model/...)
          final pathParts = path.split(destination.path);
          if (pathParts.length >= 2) {
            final model = pathParts[pathParts.length - 1];
            final brand = pathParts[pathParts.length - 2];
            await _logOperation(brand, model, logEntry, customBaseDir: customBaseDir);
          }
          // Save CRC32 hash file
          final hashFile = File("$newPath.crc32");
          final content = 'Filename: $entityName\nCRC32: $crc32\n';
          await hashFile.writeAsString(content, flush: true);
        } else if (entity is Directory) {
          await copyDirectory(entity, Directory(newPath), customBaseDir: customBaseDir);
        }
      }
      logger.i('Successfully copied directory: ${source.path} to ${destination.path}');
    } catch (e) {
      logger.e('Error during directory copy ${source.path} to ${destination.path}: $e');
      if (await destination.exists()) {
        await destination.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> deleteFile(String brand, String model, String fileName) async {
    final modelPath = await folderManager.getModelPath(brand, model);
    final file = File(path.join(modelPath, fileName));
    if (!await file.exists()) {
      logger.e('File does not exist: ${file.path}');
      throw Exception('File does not exist: ${file.path}');
    }
    if (!await _canAccessFile(file)) {
      logger.e('File is not accessible: ${file.path}');
      throw Exception('File is not accessible: ${file.path}');
    }
    try {
      await file.delete();
      await updateSoftwareHashes(brand, model, fileName, '', remove: true);
      final logEntry = 'DELETE: $fileName at ${DateTime.now()}';
      await _logOperation(brand, model, logEntry);
    } catch (e) {
      logger.e('Delete failed for $fileName: $e');
      rethrow;
    }
  }

  Future<void> deleteDirectory(String brand, String model, String dirName) async {
    final modelPath = await folderManager.getModelPath(brand, model);
    final directory = Directory(path.join(modelPath, dirName));
    if (!await directory.exists()) {
      logger.e('Directory does not exist: ${directory.path}');
      throw Exception('Directory does not exist: ${directory.path}');
    }
    try {
      await directory.delete(recursive: true);
      final logEntry = 'DELETE DIRECTORY: $dirName at ${DateTime.now()}';
      await _logOperation(brand, model, logEntry);
    } catch (e) {
      logger.e('Delete failed for directory $dirName: $e');
      rethrow;
    }
  }

  Future<void> uploadFile(String brand, String model, PlatformFile file, {Map<String, Map<String, String>>? softwareHashes}) async {
    final modelPath = await folderManager.getModelPath(brand, model);
    final destFile = File(path.join(modelPath, file.name));
    final sourceFile = File(file.path!);

    logger.i('Uploading file: ${file.name}, Source path: ${file.path}, Size: ${file.size} bytes');
    if (!await sourceFile.exists()) {
      logger.e('Source file does not exist: ${file.path}');
      throw Exception('Source file does not exist: ${file.path}');
    }
    if (!await _canAccessFile(sourceFile)) {
      logger.e('Source file is not accessible: ${file.path}');
      throw Exception('Source file is not accessible: ${file.path}');
    }

    // Perform SHA-1 hash check if softwareHashes provided
    if (softwareHashes != null) {
      final key = "$brand-$model";
      if (softwareHashes.containsKey(key) && softwareHashes[key]!.containsKey(file.name)) {
        final computedHash = await generateCRC32(sourceFile);
        final expectedHash = softwareHashes[key]![file.name]!;
        if (computedHash != expectedHash) {
          throw Exception('File does not match: hash mismatch for ${file.name}');
        }
      }
    }

    try {
      final crc32 = await generateCRC32(sourceFile);
      if (!await destFile.parent.exists()) {
        await destFile.parent.create(recursive: true);
      }
      if (await destFile.exists()) {
        await destFile.delete();
      }
      await sourceFile.copy(destFile.path);
      await updateSoftwareHashes(brand, model, file.name, crc32);
      final logEntry = 'UPLOAD: ${file.name} (${file.size} bytes, CRC32: $crc32) at ${DateTime.now()}';
      await _logOperation(brand, model, logEntry);
    } catch (e) {
      logger.e('Upload failed for ${file.name}: $e');
      if (await destFile.exists()) {
        await destFile.delete();
      }
      rethrow;
    }
  }
}