import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:logger/logger.dart';
import 'package:hashlib/hashlib.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/folder_manager.dart';


class CopyOperationResult {
  final bool success;
  final List<String> skippedFiles;
  final List<String> replacedFiles;
  final String? error;

  CopyOperationResult({
    required this.success,
    this.skippedFiles = const [],
    this.replacedFiles = const [],
    this.error,
  });
}

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
      final bytes = await file.readAsBytes();
      final hash = crc32.convert(bytes);
      return hash.hex().toUpperCase();
    } catch (e) {
      logger.e('Failed to generate CRC32 for ${file.path}: $e');
      throw Exception('Failed to generate CRC32: $e');
    }
  }

  bool _isPathWithinBank(String sourcePath, String bankPath) {
    try {
      final normalizedSource = path.normalize(path.absolute(sourcePath));
      final normalizedBank = path.normalize(path.absolute(bankPath));
      return normalizedSource.startsWith(normalizedBank);
    } catch (e) {
      logger.e('Error validating path: $e');
      return false;
    }
  }

  Future<void> _logOperation(String brand, String series, String model, String entry, {String? customBaseDir}) async {
    final baseDir = customBaseDir ?? await folderManager.appDataPath;
    final logDir = Directory(path.join(baseDir, brand, series, model));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final logFile = File(path.join(logDir.path, 'model_log.txt'));
    try {
      await logFile.writeAsString('$entry\n', mode: FileMode.append, flush: true);
    } catch (e) {
      logger.e('Error writing to log file ${logFile.path}: $e');
      rethrow;
    }
  }

  Future<void> _logOperationLegacy(String brand, String model, String entry, {String? customBaseDir}) async {
    final baseDir = customBaseDir ?? await folderManager.appDataPath;
    final logDir = Directory(path.join(baseDir, brand, model));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final logFile = File(path.join(logDir.path, 'model_log.txt'));
    try {
      await logFile.writeAsString('$entry\n', mode: FileMode.append, flush: true);
    } catch (e) {
      logger.e('Error writing to log file ${logFile.path}: $e');
      rethrow;
    }
  }

  Future<void> _writeSoftwareHashes(Directory destDir, Map<String, String> hashes) async {
    final hashFile = File(path.join(destDir.path, 'software_hashes.txt'));
    final content = hashes.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    await hashFile.writeAsString(content, flush: true);
  }

  Future<Map<String, String>> _readSoftwareHashes(Directory sourceDir) async {
    final hashFile = File(path.join(sourceDir.path, 'software_hashes.txt'));
    if (!await hashFile.exists()) {
      return {};
    }
    try {
      final content = await hashFile.readAsString();
      final hashes = <String, String>{};
      for (var line in content.split('\n')) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(':');
        if (parts.length == 2) {
          hashes[parts[0].trim()] = parts[1].trim();
        }
      }
      return hashes;
    } catch (e) {
      logger.e('Error reading software_hashes.txt from ${sourceDir.path}: $e');
      return {};
    }
  }

  Future<void> copyFileToLocation({
    required String sourcePath,
    required String fileName,
    required String brand,
    required String series,
    required String model,
    required String destinationPath,
    Map<String, Map<String, String>>? softwareHashes,
  }) async {
    logger.i('Starting import operation: $sourcePath to $destinationPath');
    final sourceFile = File(sourcePath);
    final sourceDir = Directory(sourcePath);
    final destPath = path.join(destinationPath, brand, series, model);
    Map<String, String> collectedHashes = {};

    if (await sourceDir.exists()) {
      final destDir = Directory(destPath);
      try {
        if (!await destDir.parent.exists()) {
          await destDir.parent.create(recursive: true);
        }
        if (await destDir.exists()) {
          await destDir.delete(recursive: true);
        }
        final key = "$brand-$series-$model";
        if (softwareHashes != null && softwareHashes.containsKey(key)) {
          await for (var entity in sourceDir.list(recursive: true)) {
            if (entity is File) {
              final fileBaseName = path.basename(entity.path);
              if (softwareHashes[key]!.containsKey(fileBaseName)) {
                final computedHash = await generateCRC32(entity);
                final expectedHash = softwareHashes[key]![fileBaseName]!;
                if (computedHash != expectedHash) {
                  throw Exception('File does not match: hash mismatch for $fileBaseName (expected: $expectedHash, got: $computedHash)');
                }
              }
            }
          }
        }
        collectedHashes = await copyDirectory(sourceDir, destDir, customBaseDir: destinationPath);
        await _writeSoftwareHashes(destDir, collectedHashes);
        final logEntry = 'COPY DIRECTORY: $fileName to $destPath at ${DateTime.now()}';
        await _logOperation(brand, series, model, logEntry, customBaseDir: destinationPath);
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
      final key = "$brand-$series-$model";
      if (softwareHashes != null && softwareHashes.containsKey(key) && softwareHashes[key]!.containsKey(fileName)) {
        final computedHash = await generateCRC32(sourceFile);
        final expectedHash = softwareHashes[key]![fileName]!;
        if (computedHash != expectedHash) {
          throw Exception('File does not match: hash mismatch for $fileName (expected: $expectedHash, got: $computedHash)');
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
        collectedHashes[fileName] = crc32;

        await _updateHashFileForFile(Directory(destPath), fileName, crc32);

        final logEntry = 'COPY FILE: $fileName to $destPath (CRC32: $crc32) at ${DateTime.now()}';
        await _logOperation(brand, series, model, logEntry, customBaseDir: destinationPath);
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

  Future<void> _updateHashFileForFile(Directory destDir, String fileName, String hash) async
  {
    final hashFile = File(path.join(destDir.path, 'software_hashes.txt'));

    try {
      String content = '';
      if (await hashFile.exists()) {
        content = await hashFile.readAsString();
      }

      final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
      final updatedLines = <String>[];
      bool found = false;

      for (var line in lines) {
        final parts = line.split(':');
        if (parts.length == 2) {
          final existingFileName = parts[0].trim();
          if (existingFileName == fileName) {
            updatedLines.add('$fileName: $hash');
            found = true;
          } else {
            updatedLines.add(line);
          }
        }
      }

      if (!found) {
        updatedLines.add('$fileName: $hash');
      }

      await hashFile.writeAsString(updatedLines.join('\n') + '\n', flush: true);
      logger.i('Updated software_hashes.txt for $fileName with hash $hash');
    } catch (e) {
      logger.e('Error updating hash file: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> copyDirectory(Directory source, Directory destination, {String? customBaseDir}) async
  {
    logger.i('Starting directory copy: ${source.path} to ${destination.path}');
    if (!await source.exists()) {
      logger.e('Source directory does not exist: ${source.path}');
      throw Exception('Source directory does not exist: ${source.path}');
    }
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    Map<String, String> hashes = {};
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
          hashes[entityName] = crc32;
          final logEntry = 'COPY FILE: $entityName to $newPath (CRC32: $crc32) at ${DateTime.now()}';
          final pathParts = path.split(destination.path);
          if (pathParts.length >= 3 && customBaseDir != null) {
            final model = pathParts[pathParts.length - 1];
            final series = pathParts[pathParts.length - 2];
            final brand = pathParts[pathParts.length - 3];
            await _logOperation(brand, series, model, logEntry, customBaseDir: customBaseDir);
          }
        } else if (entity is Directory) {
          final subHashes = await copyDirectory(entity, Directory(newPath), customBaseDir: customBaseDir);
          subHashes.forEach((key, value) {
            hashes[path.join(entityName, key)] = value;
          });
        }
      }
      logger.i('Successfully copied directory: ${source.path} to ${destination.path}');
      return hashes;
    } catch (e) {
      logger.e('Error during directory copy ${source.path} to ${destination.path}: $e');
      if (await destination.exists()) {
        await destination.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> copyToExternal({
    required String brand,
    required String series,
    required String model,
    required String fileName,
    required String destinationPath,
  }) async
  {
    logger.i('=== copyToExternal START ===');
    logger.i('Brand: $brand, Series: $series, Model: $model');
    logger.i('FileName: $fileName (empty = copy entire model dir)');
    logger.i('Destination: $destinationPath');

    try {
      final prefs = await SharedPreferences.getInstance();
      final bankPath = prefs.getString('software_bank_path');

      String sourcePath;
      if (bankPath == null || bankPath.isEmpty) {
        logger.e('Software bank path not configured in preferences');
        throw Exception('Software bank path not configured. Please set it in settings.');
      }

      sourcePath = path.join(bankPath, brand, series, model);
      logger.i('Using software bank path: $sourcePath');

      final sourcePathDir = Directory(sourcePath);
      if (!await sourcePathDir.exists()) {
        logger.e('Source model directory does not exist at: $sourcePath');
        throw Exception('Model directory not found at $sourcePath');
      }
      logger.i('✓ Source model directory exists');

      // If fileName is empty, copy the entire model directory with full hierarchy
      if (fileName.isEmpty) {
        logger.i('Copying entire model directory with hierarchy');
        final destDir = Directory(path.join(destinationPath, brand, series, model));

        logger.i('Destination for full model: ${destDir.path}');

        try {
          if (await destDir.exists()) {
            logger.w('Destination directory already exists. Deleting: ${destDir.path}');
            await destDir.delete(recursive: true);
          }

          logger.i('Creating new destination directory');
          await destDir.create(recursive: true);

          final sourceContents = await sourcePathDir.list(recursive: true).toList();
          logger.i('Total items in source: ${sourceContents.length}');

          int filesCopied = 0;
          final sourceHashes = await _readSoftwareHashes(sourcePathDir);
          Map<String, String> collectedHashes = {};

          await for (var entity in sourcePathDir.list(recursive: true)) {
            if (entity is File) {
              final relPath = path.relative(entity.path, from: sourcePath);
              final destFile = File(path.join(destDir.path, relPath));

              logger.i('Copying file: $relPath');

              if (!await destFile.parent.exists()) {
                await destFile.parent.create(recursive: true);
              }

              await entity.copy(destFile.path);
              logger.i('✓ File copied');
              filesCopied++;

              final hashFileName = path.basename(entity.path);
              if (sourceHashes.containsKey(hashFileName)) {
                collectedHashes[hashFileName] = sourceHashes[hashFileName]!;
              }
            }
          }

          logger.i('Total files copied: $filesCopied');

          if (collectedHashes.isNotEmpty) {
            logger.i('Writing ${collectedHashes.length} hashes to destination');
            await _writeSoftwareHashes(destDir, collectedHashes);
          }

          final logEntry = 'COPY TO EXTERNAL: Full model to ${destDir.path} at ${DateTime.now()}';
          await _logOperation(brand, series, model, logEntry);

          logger.i('=== copyToExternal COMPLETED (Full Model) ===');
        } catch (e) {
          logger.e('Directory copy to external failed: $e');
          if (await destDir.exists()) {
            await destDir.delete(recursive: true);
          }
          rethrow;
        }
        return;
      }

      // Otherwise, copy specific file or subdirectory
      final sourceEntityPath = path.join(sourcePath, fileName);
      final sourceFile = File(sourceEntityPath);
      final sourceDir = Directory(sourceEntityPath);
      Map<String, String> collectedHashes = {};

      final destDirCheck = Directory(destinationPath);
      if (!await destDirCheck.exists()) {
        logger.w('Destination does not exist. Creating: $destinationPath');
        await destDirCheck.create(recursive: true);
      }
      logger.i('Destination directory ready');

      logger.i('Reading software hashes from source...');
      final sourceHashes = await _readSoftwareHashes(sourcePathDir);
      logger.i('Found ${sourceHashes.length} hashes in source');

      if (await sourceDir.exists()) {
        logger.i('Source is a directory: $sourceEntityPath');

        final dirName = fileName;
        final destDir = Directory(path.join(destinationPath, dirName));

        logger.i('Destination for directory: ${destDir.path}');

        try {
          if (await destDir.exists()) {
            logger.w('Destination directory already exists. Deleting: ${destDir.path}');
            await destDir.delete(recursive: true);
          }

          logger.i('Creating new destination directory');
          await destDir.create(recursive: true);

          final sourceContents = await sourceDir.list(recursive: true).toList();
          logger.i('Total items in source: ${sourceContents.length}');

          int filesCopied = 0;
          await for (var entity in sourceDir.list(recursive: true)) {
            if (entity is File) {
              final relPath = path.relative(entity.path, from: sourceDir.path);
              final destFile = File(path.join(destDir.path, relPath));

              logger.i('Copying file: $relPath');

              if (!await destFile.parent.exists()) {
                await destFile.parent.create(recursive: true);
              }

              await entity.copy(destFile.path);
              logger.i('✓ File copied');
              filesCopied++;

              final hashFileName = path.basename(entity.path);
              if (sourceHashes.containsKey(hashFileName)) {
                collectedHashes[hashFileName] = sourceHashes[hashFileName]!;
              }
            }
          }

          logger.i('Total files copied: $filesCopied');

          if (collectedHashes.isNotEmpty) {
            logger.i('Writing ${collectedHashes.length} hashes to destination');
            await _writeSoftwareHashes(destDir, collectedHashes);
          }

          final logEntry = 'COPY TO EXTERNAL: $fileName (directory) to ${destDir.path} at ${DateTime.now()}';
          await _logOperation(brand, series, model, logEntry);

          logger.i('=== copyToExternal COMPLETED (Directory) ===');
        } catch (e) {
          logger.e('Directory copy to external failed: $e');
          if (await destDir.exists()) {
            await destDir.delete(recursive: true);
          }
          rethrow;
        }
        return;
      }

      if (await sourceFile.exists()) {
        logger.i('Source is a file: $sourceEntityPath');

        final destFile = File(path.join(destinationPath, fileName));

        if (!await _canAccessFile(sourceFile)) {
          logger.e('Source file is not accessible: ${sourceFile.path}');
          throw Exception('Source file is not accessible: ${sourceFile.path}');
        }

        try {
          if (!await Directory(destinationPath).exists()) {
            await Directory(destinationPath).create(recursive: true);
          }
          if (await destFile.exists()) {
            await destFile.delete();
          }

          logger.i('Copying file to destination');
          await sourceFile.copy(destFile.path);
          logger.i('✓ File copied to ${destFile.path}');

          if (sourceHashes.containsKey(fileName)) {
            collectedHashes[fileName] = sourceHashes[fileName]!;
            logger.i('Using existing hash: ${sourceHashes[fileName]!}');
          } else {
            final crc32 = await generateCRC32(sourceFile);
            collectedHashes[fileName] = crc32;
            logger.i('Calculated hash: $crc32');
          }

          await _writeSoftwareHashes(Directory(destinationPath), collectedHashes);
          logger.i('✓ Hash file written');

          final logEntry = 'COPY TO EXTERNAL: $fileName to ${destFile.path} at ${DateTime.now()}';
          await _logOperation(brand, series, model, logEntry);

          logger.i('=== copyToExternal COMPLETED (File) ===');
        } catch (e) {
          logger.e('File copy to external failed: $e');
          if (await destFile.exists()) {
            await destFile.delete();
          }
          rethrow;
        }
        return;
      }

      logger.e('Source does not exist: $sourceEntityPath');
      throw Exception('Source does not exist: $sourceEntityPath');

    } catch (e) {
      logger.e('=== copyToExternal FAILED ===');
      logger.e('Error: $e');
      rethrow;
    }
  }

  Future<CopyOperationResult> copyFileToLocationWithProgress({
    required String sourcePath,
    required String fileName,
    required String brand,
    required String series,
    required String model,
    required String destinationPath,
    Map<String, Map<String, String>>? softwareHashes,
    required void Function(String, int, int) onProgressUpdate,
    required Future<String> Function(String, String) onFileExists, // Callback for UI to handle file conflicts
  }) async
  {
    logger.i('Starting import operation with progress: $sourcePath to $destinationPath');

    final sourceFile = File(sourcePath);
    final sourceDir = Directory(sourcePath);
    final destPath = path.join(destinationPath, brand, series, model);

    final skippedFiles = <String>[];
    final replacedFiles = <String>[];

    int totalFiles = 0;
    int currentFile = 0;

    try {
      // Count total files for progress tracking
      if (await sourceDir.exists()) {
        totalFiles = await _countFilesInDirectory(sourceDir);
      } else if (await sourceFile.exists()) {
        totalFiles = 1;
      }

      if (await sourceDir.exists()) {
        final destDir = Directory(destPath);

        if (!await destDir.parent.exists()) {
          await destDir.parent.create(recursive: true);
        }

        final key = "$brand-$series-$model";
        if (softwareHashes != null && softwareHashes.containsKey(key)) {
          // Validate files first
          onProgressUpdate('Validating files...', 0, totalFiles);
          await for (var entity in sourceDir.list(recursive: true)) {
            if (entity is File) {
              final fileBaseName = path.basename(entity.path);
              if (softwareHashes[key]!.containsKey(fileBaseName)) {
                final computedHash = await generateCRC32(entity);
                final expectedHash = softwareHashes[key]![fileBaseName]!;
                if (computedHash != expectedHash) {
                  throw Exception('File does not match: hash mismatch for $fileBaseName (expected: $expectedHash, got: $computedHash)');
                }
              }
            }
          }
        }

        // Copy files with progress and conflict handling
        await _copyDirectoryWithProgress(
          sourceDir,
          destDir,
          customBaseDir: destinationPath,
          onProgressUpdate: (fileName, current, total) {
            currentFile = current;
            onProgressUpdate(fileName, current, total);
          },
          onFileExists: onFileExists,
          skippedFiles: skippedFiles,
          replacedFiles: replacedFiles,
        );

        final logEntry = 'COPY DIRECTORY: $fileName to $destPath at ${DateTime.now()}';
        await _logOperation(brand, series, model, logEntry, customBaseDir: destinationPath);
        logger.i('Directory copy completed: ${destDir.path}');

      } else if (await sourceFile.exists()) {
        final destFile = File(path.join(destPath, fileName));

        if (!await _canAccessFile(sourceFile)) {
          throw Exception('Source file is not accessible: ${sourceFile.path}');
        }

        final key = "$brand-$series-$model";
        if (softwareHashes != null && softwareHashes.containsKey(key) && softwareHashes[key]!.containsKey(fileName)) {
          onProgressUpdate('Validating $fileName...', 0, totalFiles);
          final computedHash = await generateCRC32(sourceFile);
          final expectedHash = softwareHashes[key]![fileName]!;
          if (computedHash != expectedHash) {
            throw Exception('File does not match: hash mismatch for $fileName (expected: $expectedHash, got: $computedHash)');
          }
        }

        onProgressUpdate('Copying $fileName...', 1, 1);

        // Check if file exists and get user decision
        if (await destFile.exists()) {
          final decision = await onFileExists(fileName, destFile.path);
          if (decision == 'skip') {
            skippedFiles.add(fileName);
            logger.i('Skipped file: $fileName');
            return CopyOperationResult(
              success: true,
              skippedFiles: skippedFiles,
              replacedFiles: replacedFiles,
            );
          } else if (decision == 'skipAll') {
            // This would need to be handled differently for multiple files
            skippedFiles.add(fileName);
            logger.i('Skipped file: $fileName');
            return CopyOperationResult(
              success: true,
              skippedFiles: skippedFiles,
              replacedFiles: replacedFiles,
            );
          }
          // If replace, continue with copy
          replacedFiles.add(fileName);
        }

        if (!await Directory(destPath).exists()) {
          await Directory(destPath).create(recursive: true);
        }
        if (await destFile.exists()) {
          await destFile.delete();
        }

        final crc32 = await generateCRC32(sourceFile);
        await sourceFile.copy(destFile.path);
        await _updateHashFileForFile(Directory(destPath), fileName, crc32);

        final logEntry = 'COPY FILE: $fileName to $destPath (CRC32: $crc32) at ${DateTime.now()}';
        await _logOperation(brand, series, model, logEntry, customBaseDir: destinationPath);
        logger.i('File copy completed: ${destFile.path}');
      } else {
        throw Exception('Source does not exist: $sourcePath');
      }

      return CopyOperationResult(
        success: true,
        skippedFiles: skippedFiles,
        replacedFiles: replacedFiles,
      );
    } catch (e) {
      logger.e('Import operation failed: $e');
      return CopyOperationResult(
        success: false,
        error: e.toString(),
        skippedFiles: skippedFiles,
        replacedFiles: replacedFiles,
      );
    }
  }

// Update the directory copy method to handle conflicts
  Future<void> _copyDirectoryWithProgress(
      Directory source,
      Directory destination, {
        String? customBaseDir,
        required void Function(String, int, int) onProgressUpdate,
        required Future<String> Function(String, String) onFileExists,
        required List<String> skippedFiles,
        required List<String> replacedFiles,
      }) async {
    if (!await source.exists()) {
      throw Exception('Source directory does not exist: ${source.path}');
    }

    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    int totalFiles = await _countFilesInDirectory(source);
    int currentFile = 0;
    bool skipAll = false;

    await for (var entity in source.list(recursive: false)) {
      final entityName = path.basename(entity.path);
      final newPath = path.join(destination.path, entityName);

      if (entity is File) {
        currentFile++;
        onProgressUpdate(entityName, currentFile, totalFiles);

        if (!await _canAccessFile(entity)) {
          throw Exception('File is not accessible: ${entity.path}');
        }

        final destFile = File(newPath);

        // Check if file exists and handle conflict
        if (await destFile.exists() && !skipAll) {
          final decision = await onFileExists(entityName, newPath);

          if (decision == 'skip') {
            skippedFiles.add(entityName);
            continue;
          } else if (decision == 'skipAll') {
            skipAll = true;
            skippedFiles.add(entityName);
            continue;
          } else if (decision == 'replace') {
            replacedFiles.add(entityName);
            await destFile.delete();
          }
        } else if (await destFile.exists() && skipAll) {
          skippedFiles.add(entityName);
          continue;
        }

        final crc32 = await generateCRC32(entity);
        await entity.copy(newPath);

        // Log the operation
        final pathParts = path.split(destination.path);
        if (pathParts.length >= 3 && customBaseDir != null) {
          final model = pathParts[pathParts.length - 1];
          final series = pathParts[pathParts.length - 2];
          final brand = pathParts[pathParts.length - 3];
          final logEntry = 'COPY FILE: $entityName to $newPath (CRC32: $crc32) at ${DateTime.now()}';
          await _logOperation(brand, series, model, logEntry, customBaseDir: customBaseDir);
        }
      } else if (entity is Directory) {
        await _copyDirectoryWithProgress(
          entity,
          Directory(newPath),
          customBaseDir: customBaseDir,
          onProgressUpdate: onProgressUpdate,
          onFileExists: onFileExists,
          skippedFiles: skippedFiles,
          replacedFiles: replacedFiles,
        );
      }
    }
  }



  Future<List<Map<String, dynamic>>> _getAllFilesForExport({
    List<String>? models,
    List<String>? files,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bankPath = prefs.getString('software_bank_path');

    if (bankPath == null || bankPath.isEmpty) {
      throw Exception('Software bank path not configured');
    }

    final fileList = <Map<String, dynamic>>[];

    if (models != null) {
      for (final modelKey in models) {
        final parts = modelKey.split('-');
        if (parts.length == 3) {
          final brand = parts[0], series = parts[1], model = parts[2];
          // Only add directory entry for the model itself - don't add individual files
          fileList.add({
            'brand': brand,
            'series': series,
            'model': model,
            'fileName': '',
            'type': 'directory'
          });
        }
      }
    } else if (files != null) {
      for (final fileKey in files) {
        final parts = fileKey.split('-');
        if (parts.length >= 4) {
          final brand = parts[0], series = parts[1], model = parts[2];
          final fileName = parts.sublist(3).join('-');
          fileList.add({
            'brand': brand,
            'series': series,
            'model': model,
            'fileName': fileName,
            'type': 'file'
          });
        }
      }
    }

    return fileList;
  }

  Future<void> copyToExternalWithProgress({
    List<String>? models,
    List<String>? files,
    required String destinationPath,
    required void Function(String, int, int) onProgressUpdate,
  }) async {
    logger.i('=== copyToExternalWithProgress START ===');

    try {
      final fileList = await _getAllFilesForExport(
        models: models,
        files: files,
      );

      final totalFiles = fileList.length;
      int currentFile = 0;

      // Process each file with progress updates
      for (final fileInfo in fileList) {
        currentFile++;
        final brand = fileInfo['brand'] as String;
        final series = fileInfo['series'] as String;
        final model = fileInfo['model'] as String;
        final fileName = fileInfo['fileName'] as String;
        final type = fileInfo['type'] as String;

        if (type == 'directory') {
          onProgressUpdate('Copying $brand/$series/$model...', currentFile, totalFiles);
          await copyToExternal(
            brand: brand,
            series: series,
            model: model,
            fileName: fileName,
            destinationPath: destinationPath,
          );
        } else {
          onProgressUpdate('Copying $fileName...', currentFile, totalFiles);
          await copyToExternal(
            brand: brand,
            series: series,
            model: model,
            fileName: fileName,
            destinationPath: destinationPath,
          );
        }
      }

      logger.i('=== copyToExternalWithProgress COMPLETED ===');
    } catch (e) {
      logger.e('=== copyToExternalWithProgress FAILED ===');
      rethrow;
    }
  }

  Future<int> _countFilesInDirectory(Directory dir) async {
    int count = 0;
    await for (var entity in dir.list(recursive: true)) {
      if (entity is File) {
        count++;
      }
    }
    return count;
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
      final logEntry = 'DELETE: $fileName at ${DateTime.now()}';
      await _logOperationLegacy(brand, model, logEntry);
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
      await _logOperationLegacy(brand, model, logEntry);
    } catch (e) {
      logger.e('Delete failed for directory $dirName: $e');
      rethrow;
    }
  }

  Future<void> uploadFile(String brand, String model, PlatformFile file, {Map<String, Map<String, String>>? softwareHashes}) async {
    final prefs = await SharedPreferences.getInstance();
    final bankPath = prefs.getString('software_bank_path');
    if (bankPath != null && !_isPathWithinBank(file.path!, bankPath)) {
      logger.e('Uploading not allowed from outside software bank: ${file.path}');
      throw Exception('Uploading only allowed from software bank location');
    }

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

    final key = "$brand-$model";
    if (softwareHashes != null && softwareHashes.containsKey(key) && softwareHashes[key]!.containsKey(file.name)) {
      final computedHash = await generateCRC32(sourceFile);
      final expectedHash = softwareHashes[key]![file.name]!;
      if (computedHash != expectedHash) {
        throw Exception('File does not match: hash mismatch for ${file.name} (expected: $expectedHash, got: $computedHash)');
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
      final hashFile = File(path.join(modelPath, 'software_hashes.txt'));
      String content = '';
      if (await hashFile.exists()) {
        content = await hashFile.readAsString();
      }
      content += '${file.name}: $crc32\n';
      await hashFile.writeAsString(content, flush: true);
      final logEntry = 'UPLOAD: ${file.name} (${file.size} bytes, CRC32: $crc32) at ${DateTime.now()}';
      await _logOperationLegacy(brand, model, logEntry);
    } catch (e) {
      logger.e('Upload failed for ${file.name}: $e');
      if (await destFile.exists()) {
        await destFile.delete();
      }
      rethrow;
    }
  }





}