import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:server/utils/folder_manager.dart';
import 'package:server/services/file_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'FileViewerScreen.dart';
import 'package:lottie/lottie.dart';

class CustomFilePickerDialog extends StatefulWidget {
  final String title;
  final bool allowFiles;
  final bool allowFolders;
  final String? initialDirectory;

  const CustomFilePickerDialog({
    Key? key,
    required this.title,
    this.allowFiles = true,
    this.allowFolders = true,
    this.initialDirectory,
  }) : super(key: key);

  @override
  State<CustomFilePickerDialog> createState() => _CustomFilePickerDialogState();
}

class _CustomFilePickerDialogState extends State<CustomFilePickerDialog> {
  Directory? currentDirectory;
  List<FileSystemEntity> contents = [];
  String? selectedPath;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeDirectory();
  }

  Future<void> _initializeDirectory() async {
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDriveSelection();
      });
      return;
    }

    String initialPath = widget.initialDirectory ?? '';
    try {
      if (initialPath.isEmpty) {
        if (Platform.isLinux || Platform.isMacOS) {
          initialPath = Platform.environment['HOME'] ?? '/home';
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          initialPath = appDir.path;
        }
      }

      final testDir = Directory(initialPath);
      if (!await testDir.exists()) {
        throw Exception('Directory does not exist: $initialPath');
      }

      currentDirectory = testDir;
      selectedPath = testDir.path;
    } catch (e) {
      try {
        if (Platform.isLinux || Platform.isMacOS) {
          currentDirectory = Directory('/');
          selectedPath = '/';
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          currentDirectory = Directory(appDir.path);
          selectedPath = appDir.path;
        }
      } catch (fallbackError) {
        currentDirectory = Directory('.');
        selectedPath = '.';
      }
    }

    await _loadContents();
  }

  Future<void> _loadContents() async {
    if (currentDirectory == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final entities = await currentDirectory!.list().toList();
      entities.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return path.basename(a.path).toLowerCase().compareTo(path.basename(b.path).toLowerCase());
      });

      setState(() {
        contents = entities;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        contents = [];
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading directory: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToDirectory(Directory directory) async {
    setState(() {
      currentDirectory = directory;
      selectedPath = directory.path;
    });
    await _loadContents();
  }

  Future<void> _navigateUp() async {
    if (currentDirectory?.parent != null && !currentDirectory!.path.endsWith(':\\')) {
      await _navigateToDirectory(currentDirectory!.parent);
    } else if (Platform.isWindows) {
      _showDriveSelection();
    }
  }

  void _showDriveSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Drive'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder<List<String>>(
            future: _getAvailableDrives(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No drives found'));
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final drive = snapshot.data![index];
                  return ListTile(
                    leading: Icon(Icons.storage, color: Colors.blue.shade600),
                    title: Text(drive),
                    subtitle: Text(_getDriveLabel(drive)),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        currentDirectory = Directory(drive);
                        selectedPath = drive;
                      });
                      if (widget.allowFolders && !widget.allowFiles) {
                        Navigator.of(context).pop(drive);
                      } else {
                        _navigateToDirectory(Directory(drive));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                currentDirectory = Directory('C:\\');
                selectedPath = 'C:\\';
              });
              _loadContents();
            },
            child: const Text('Cancel'),
          ),
          if (widget.allowFolders && currentDirectory != null)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(currentDirectory!.path),
              child: const Text('Select This Drive'),
            ),
        ],
      ),
    );
  }

  Future<List<String>> _getAvailableDrives() async {
    if (!Platform.isWindows) return [];
    final drives = <String>[];
    for (int i = 65; i <= 90; i++) {
      final driveLetter = String.fromCharCode(i);
      final drivePath = '$driveLetter:\\';
      try {
        final directory = Directory(drivePath);
        if (await directory.exists()) {
          drives.add(drivePath);
        }
      } catch (e) {
        // Skip inaccessible drives
      }
    }
    return drives;
  }

  String _getDriveLabel(String drive) {
    switch (drive.toUpperCase()) {
      case 'A:\\':
        return 'Floppy Disk';
      case 'C:\\':
        return 'Local Disk (C:)';
      case 'D:\\':
        return 'Local Disk (D:)';
      default:
        return 'Drive ${drive.substring(0, 2)}';
    }
  }

  Widget _buildPathBreadcrumb() {
    if (currentDirectory == null) return const SizedBox();
    final displayPath = currentDirectory!.path.length > 60
        ? '...${currentDirectory!.path.substring(currentDirectory!.path.length - 57)}'
        : currentDirectory!.path;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(
            Platform.isWindows && currentDirectory!.path.endsWith(':\\') ? Icons.storage : Icons.folder,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayPath,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (Platform.isWindows)
            IconButton(
              onPressed: _showDriveSelection,
              icon: Icon(Icons.more_horiz, size: 16, color: Colors.grey.shade600),
              tooltip: 'Change Drive',
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildFileSystemItem(FileSystemEntity entity) {
    final isDirectory = entity is Directory;
    final name = path.basename(entity.path);
    final isSelectable = (isDirectory && widget.allowFolders) || (!isDirectory && widget.allowFiles);
    final isSelected = selectedPath == entity.path;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: isDirectory
            ? Icon(Icons.folder, color: Colors.amber.shade700, size: 28)
            : Icon(Icons.insert_drive_file, color: Colors.blue.shade600, size: 24),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelectable ? null : Colors.grey.shade500,
          ),
        ),
        subtitle: isDirectory ? const Text('Folder • Click to enter') : Text(_getFileInfo(entity as File)),
        trailing: isDirectory
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.allowFolders && isSelected)
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
              if (widget.allowFolders && isSelected) const SizedBox(width: 6),
              Text('ENTER', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: Colors.blue.shade700, size: 12),
            ],
          ),
        )
            : isSelectable && isSelected
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
              const SizedBox(width: 6),
              Text('SELECTED', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        )
            : null,
        onTap: () {
          if (isDirectory) {
            _navigateToDirectory(entity);
          } else if (widget.allowFiles) {
            setState(() {
              selectedPath = entity.path;
            });
          }
        },
        onLongPress: isDirectory && widget.allowFolders
            ? () {
          setState(() {
            selectedPath = entity.path;
          });
        }
            : null,
      ),
    );
  }

  String _getFileInfo(File file) {
    try {
      final stat = file.statSync();
      return 'File • ${_formatFileSize(stat.size)}';
    } catch (e) {
      return 'File';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              ],
            ),
            if (widget.allowFolders) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Folders: Tap to enter • Long press to select', style: TextStyle(fontSize: 12, color: Colors.orange.shade700))),
                  ],
                ),
              ),
            ],
            _buildPathBreadcrumb(),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (currentDirectory?.parent != null || Platform.isWindows) ? _navigateUp : null,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: Text(currentDirectory?.parent != null ? 'Up' : 'Drives'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                const SizedBox(width: 8),
                if (Platform.isWindows) ...[
                  ElevatedButton.icon(
                    onPressed: _showDriveSelection,
                    icon: const Icon(Icons.storage, size: 16),
                    label: const Text('Drives'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: _loadContents,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final userDir = Platform.isWindows
                          ? Directory(Platform.environment['USERPROFILE'] ?? 'C:\\Users')
                          : Directory(Platform.environment['HOME'] ?? '/home');
                      if (await userDir.exists()) {
                        await _navigateToDirectory(userDir);
                      }
                    } catch (e) {
                      // Ignore error
                    }
                  },
                  icon: const Icon(Icons.home, size: 16),
                  label: const Text('Home'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : contents.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No items in this directory', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ),
              )
                  : ListView.builder(itemCount: contents.length, itemBuilder: (context, index) => _buildFileSystemItem(contents[index])),
            ),
            if (selectedPath != null) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                child: Row(
                  children: [
                    Icon(FileSystemEntity.isDirectorySync(selectedPath!) ? Icons.folder : Icons.insert_drive_file, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected: ${path.basename(selectedPath!)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(selectedPath!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (widget.allowFolders && currentDirectory != null) || (widget.allowFiles && selectedPath != null)
                      ? () => Navigator.of(context).pop(selectedPath ?? currentDirectory!.path)
                      : null,
                  child: const Text('Select'),
                ),
                if (widget.allowFolders && currentDirectory != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(currentDirectory!.path), child: const Text('Select This Folder')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleLoadingDialog extends StatelessWidget {
  final String title;

  const SimpleLoadingDialog({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 20),
            Lottie.asset('assets/animations/file_transfer.json', width: 100, height: 100, fit: BoxFit.contain, repeat: true),
            const SizedBox(height: 20),
            Text('Please wait...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class BackupViewerScreen extends StatefulWidget {
  const BackupViewerScreen({super.key});

  @override
  _BackupViewerScreenState createState() => _BackupViewerScreenState();
}

class _BackupViewerScreenState extends State<BackupViewerScreen> {
  Directory? _selectedBackupDir;
  List<FileSystemEntity> _contents = [];
  final FileService _fileService = FileService();
  List<String> _brands = [];
  Map<String, List<String>> _models = {};
  Map<String, Map<String, String>> _softwareHashes = {};
  final Logger logger = Logger();
  FileSystemEntity? _selectedFileForCopy;

  @override
  void initState() {
    super.initState();
    // Defer _loadConfig until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadConfig();
      }
    });
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SimpleLoadingDialog(title: 'Loading configuration'),
    );

    try {
      logger.i('Fetching config from API: https://waltontvrni.com/service-model.php');
      final response = await http.get(Uri.parse('https://waltontvrni.com/service-model.php'));
      logger.i('API response status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final config = jsonDecode(response.body) as Map<String, dynamic>;
        logger.i('Parsed config: $config');

        if (!config.containsKey('brands') || config['brands'] == null) {
          logger.w('API response missing or empty "brands" key');
          throw Exception('API response missing or empty "brands" key');
        }

        final brands = List<String>.from(config['brands']);
        final models = <String, List<String>>{};
        for (var brand in brands) {
          final modelKey = '${brand}-models';
          if (config.containsKey(modelKey) && config[modelKey] != null) {
            models[brand] = List<String>.from(config[modelKey]);
          } else {
            logger.w('No models found for brand: $brand');
            models[brand] = [];
          }
        }

        final softwareHashes = <String, Map<String, String>>{};
        if (config.containsKey('software') && config['software'] != null) {
          (config['software'] as Map<String, dynamic>).forEach((key, value) {
            final hashes = <String, String>{};
            for (var item in value as List<dynamic>) {
              if (item['soft_name'] != null && item['soft_hash'] != null) {
                hashes[item['soft_name'] as String] = item['soft_hash'] as String;
              }
            }
            softwareHashes[key] = hashes;
          });
        }

        if (mounted) {
          setState(() {
            _brands = brands;
            _models = models;
            _softwareHashes = softwareHashes;
          });
          logger.i('Config loaded: brands=$_brands, models=$_models, softwareHashes=$_softwareHashes');
        }

        final directory = await getApplicationDocumentsDirectory();
        final cacheFile = File(path.join(directory.path, 'config_cache.json'));
        await cacheFile.writeAsString(jsonEncode(config));
        logger.i('Config cached to ${cacheFile.path}');
      } else {
        throw Exception('Failed to load config: HTTP ${response.statusCode}');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      logger.e('Error loading config: $e');
      try {
        final directory = await getApplicationDocumentsDirectory();
        final cacheFile = File(path.join(directory.path, 'config_cache.json'));
        if (await cacheFile.exists()) {
          final cacheString = await cacheFile.readAsString();
          final config = jsonDecode(cacheString) as Map<String, dynamic>;
          logger.i('Loaded cached config: $config');

          final brands = List<String>.from(config['brands'] ?? []);
          final models = <String, List<String>>{};
          for (var brand in brands) {
            final modelKey = '${brand}-models';
            models[brand] = List<String>.from(config[modelKey] ?? []);
          }
          final softwareHashes = <String, Map<String, String>>{};
          if (config.containsKey('software')) {
            (config['software'] as Map<String, dynamic>).forEach((key, value) {
              final hashes = <String, String>{};
              for (var item in value as List<dynamic>) {
                if (item['soft_name'] != null && item['soft_hash'] != null) {
                  hashes[item['soft_name'] as String] = item['soft_hash'] as String;
                }
              }
              softwareHashes[key] = hashes;
            });
          }

          if (mounted) {
            setState(() {
              _brands = brands;
              _models = models;
              _softwareHashes = softwareHashes;
            });
            logger.i('Cached config applied: brands=$_brands, models=$_models, softwareHashes=$_softwareHashes');
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Loaded from cache due to error: $e'), backgroundColor: Colors.orange),
            );
          }
        } else {
          throw Exception('No cached data available');
        }
      } catch (cacheError) {
        logger.e('Error loading cached config: $cacheError');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading config: $e. Cache unavailable: $cacheError'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _selectFileOrFolder() async {
    final selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => const CustomFilePickerDialog(title: 'Select File or Folder', allowFiles: true, allowFolders: true, initialDirectory: 'C:\\'),
    );

    if (selectedPath != null && mounted) {
      if (FileSystemEntity.isDirectorySync(selectedPath)) {
        setState(() {
          _selectedBackupDir = Directory(selectedPath);
          _selectedFileForCopy = null;
        });
        await _loadBackupContents();
      } else {
        final entity = File(selectedPath);
        final parentDir = Directory(path.dirname(selectedPath));
        setState(() {
          _selectedBackupDir = parentDir;
          _selectedFileForCopy = entity;
        });
        await _loadBackupContents();
        if (mounted) _showCopyDialog(entity);
      }
    }
  }

  Future<void> _selectBackupFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      setState(() {
        _selectedBackupDir = Directory(result);
        _selectedFileForCopy = null;
      });
      await _loadBackupContents();
    }
  }

  Future<void> _loadBackupContents() async {
    if (_selectedBackupDir == null || !mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => SimpleLoadingDialog(title: 'Loading ${_selectedBackupDir!.path}'));

    try {
      final contents = await _selectedBackupDir!.list().toList();
      contents.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return path.basename(a.path).toLowerCase().compareTo(path.basename(b.path).toLowerCase());
      });

      if (mounted) {
        setState(() {
          _contents = contents;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading directory: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<bool> _validateFiles(List<File> files, String brand, String model) async {
    final key = "$brand-$model";
    if (!_softwareHashes.containsKey(key)) {
      return true; // No hashes for this brand-model, allow copy
    }

    for (var file in files) {
      final fileName = path.basename(file.path);
      if (_softwareHashes[key]!.containsKey(fileName)) {
        final computedHash = await _fileService.generateCRC32(file);
        final expectedHash = _softwareHashes[key]![fileName]!;
        if (computedHash != expectedHash) {
          logger.w('Hash mismatch for $fileName: expected $expectedHash, got $computedHash');
          return false;
        }
      }
    }
    return true;
  }

  Future<List<File>> _getFilesInDirectory(Directory dir) async {
    final files = <File>[];
    await for (var entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }
    return files;
  }

  Widget _buildBackupItem(FileSystemEntity entity) {
    final isDirectory = entity is Directory;
    final name = path.basename(entity.path);
    final isLogFile = name == FolderManager.logFileName || name == FolderManager.modelLogFileName;
    final isSelected = _selectedFileForCopy == entity;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isSelected ? 3 : 1,
      child: ListTile(
        leading: isDirectory
            ? Icon(Icons.folder, color: Colors.amber.shade700, size: 28)
            : isLogFile
            ? Icon(Icons.history, color: Colors.green.shade600, size: 24)
            : Icon(Icons.insert_drive_file, color: Colors.blue.shade600, size: 24),
        title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        subtitle: isDirectory
            ? const Text('Folder • Tap to enter')
            : Text('File • ${path.extension(name).isNotEmpty ? path.extension(name) : 'No extension'}${isSelected ? ' • Selected for copy' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDirectory) ...[
              if (isSelected)
                Container(
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                  child: TextButton.icon(
                    icon: Icon(Icons.copy, color: Colors.green.shade700, size: 16),
                    label: Text('COPY NOW', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _showCopyDialog(entity),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                  ),
                )
              else ...[
                Container(
                  decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                    icon: Icon(Icons.copy, color: Colors.blue.shade700, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedFileForCopy = entity;
                      });
                      _showCopyDialog(entity);
                    },
                    tooltip: 'Copy file',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                    icon: Icon(Icons.visibility, color: Colors.green.shade700, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FileViewerScreen(filePath: entity.path, fileName: name)),
                    ),
                    tooltip: 'View file content',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
            Container(
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
                onPressed: () => _confirmDelete(entity),
                tooltip: 'Delete',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
            if (isDirectory) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('OPEN', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, color: Colors.blue.shade700, size: 12),
                  ],
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          if (isDirectory) {
            setState(() {
              _selectedBackupDir = entity;
              _selectedFileForCopy = null;
            });
            _loadBackupContents();
          } else {
            setState(() {
              _selectedFileForCopy = entity;
            });
          }
        },
      ),
    );
  }

  void _showCopyDialog(FileSystemEntity entity) {
    String? selectedBrand;
    String? selectedModel;
    String? destinationPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Copy Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  hint: const Text('Select Brand'),
                  value: selectedBrand,
                  isExpanded: true,
                  items: _brands.isEmpty
                      ? [const DropdownMenuItem(value: null, child: Text('No brands available'))]
                      : _brands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
                  onChanged: _brands.isEmpty
                      ? null
                      : (value) {
                    logger.i('Selected brand: $value');
                    setDialogState(() {
                      selectedBrand = value;
                      selectedModel = null; // Reset model when brand changes
                    });
                  },
                ),
                if (selectedBrand != null)
                  DropdownButton<String>(
                    hint: Text(_models[selectedBrand]?.isEmpty ?? true ? 'No models available' : 'Select Model'),
                    value: selectedModel,
                    isExpanded: true,
                    items: _models[selectedBrand]?.isEmpty ?? true
                        ? [const DropdownMenuItem(value: null, child: Text('No models available'))]
                        : _models[selectedBrand]!.map((model) => DropdownMenuItem(value: model, child: Text(model))).toList(),
                    onChanged: _models[selectedBrand]?.isEmpty ?? true
                        ? null
                        : (value) {
                      logger.i('Selected model for brand $selectedBrand: $value');
                      setDialogState(() {
                        selectedModel = value;
                      });
                    },
                  ),
                ListTile(
                  title: Text('Destination: ${destinationPath ?? 'Not selected'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      final selectedPath = await showDialog<String>(
                        context: context,
                        builder: (context) => const CustomFilePickerDialog(
                          title: 'Select Destination Folder',
                          allowFiles: false,
                          allowFolders: true,
                          initialDirectory: 'C:\\',
                        ),
                      );
                      if (selectedPath != null) {
                        logger.i('Selected destination path: $selectedPath');
                        setDialogState(() {
                          destinationPath = selectedPath;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: (selectedBrand != null && selectedModel != null && destinationPath != null)
                  ? () async {
                logger.i('Copy initiated: brand=$selectedBrand, model=$selectedModel, destination=$destinationPath');
                Navigator.pop(context);
                await _copyItem(entity, selectedBrand!, selectedModel!, destinationPath!);
              }
                  : null,
              child: const Text('Copy', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyItem(FileSystemEntity entity, String brand, String model, String destinationPath) async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => SimpleLoadingDialog(title: 'Validating ${path.basename(entity.path)}'));

    try {
      List<File> filesToValidate = [];
      if (entity is File) {
        filesToValidate.add(entity);
      } else if (entity is Directory) {
        filesToValidate = await _getFilesInDirectory(entity);
      }

      // Validate all files before copying
      final isValid = await _validateFiles(filesToValidate, brand, model);
      if (!isValid) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not match: hash mismatch'), backgroundColor: Colors.red),
        );
        return;
      }

      // Filter files to copy (only those with matching hashes)
      final key = "$brand-$model";
      final filesToCopy = filesToValidate.where((file) {
        final fileName = path.basename(file.path);
        return _softwareHashes[key]?.containsKey(fileName) ?? false;
      }).toList();

      if (filesToCopy.isEmpty && entity is File) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File ${path.basename(entity.path)} not found in server configuration'), backgroundColor: Colors.red),
        );
        return;
      }

      Navigator.pop(context);
      showDialog(context: context, barrierDismissible: false, builder: (context) => SimpleLoadingDialog(title: 'Copying ${path.basename(entity.path)}'));

      final finalDestPath = path.join(destinationPath, brand, model);
      if (!await Directory(finalDestPath).exists()) {
        await Directory(finalDestPath).create(recursive: true);
      }

      if (entity is File && filesToCopy.contains(entity)) {
        await _fileService.copyFileToLocation(
          sourcePath: entity.path,
          fileName: path.basename(entity.path),
          brand: brand,
          model: model,
          destinationPath: destinationPath,
          softwareHashes: _softwareHashes,
        );
      } else if (entity is Directory) {
        for (var file in filesToCopy) {
          await _fileService.copyFileToLocation(
            sourcePath: file.path,
            fileName: path.basename(file.path),
            brand: brand,
            model: model,
            destinationPath: destinationPath,
            softwareHashes: _softwareHashes,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item copied to ${path.join(finalDestPath, path.basename(entity.path))}'), backgroundColor: Colors.green),
        );
        setState(() {
          _selectedFileForCopy = null;
        });
        await _loadBackupContents();
      }
    } catch (e) {
      logger.e('Copy failed for ${entity.path}: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showCopyAllDialog() {
    String? selectedBrand;
    String? selectedModel;
    String? destinationPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Copy All Items'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  hint: const Text('Select Brand'),
                  value: selectedBrand,
                  isExpanded: true,
                  items: _brands.isEmpty
                      ? [const DropdownMenuItem(value: null, child: Text('No brands available'))]
                      : _brands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
                  onChanged: _brands.isEmpty
                      ? null
                      : (value) {
                    logger.i('Selected brand: $value');
                    setDialogState(() {
                      selectedBrand = value;
                      selectedModel = null;
                    });
                  },
                ),
                if (selectedBrand != null)
                  DropdownButton<String>(
                    hint: Text(_models[selectedBrand]?.isEmpty ?? true ? 'No models available' : 'Select Model'),
                    value: selectedModel,
                    isExpanded: true,
                    items: _models[selectedBrand]?.isEmpty ?? true
                        ? [const DropdownMenuItem(value: null, child: Text('No models available'))]
                        : _models[selectedBrand]!.map((model) => DropdownMenuItem(value: model, child: Text(model))).toList(),
                    onChanged: _models[selectedBrand]?.isEmpty ?? true
                        ? null
                        : (value) {
                      logger.i('Selected model for brand $selectedBrand: $value');
                      setDialogState(() {
                        selectedModel = value;
                      });
                    },
                  ),
                ListTile(
                  title: Text('Destination: ${destinationPath ?? 'Not selected'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      final selectedPath = await showDialog<String>(
                        context: context,
                        builder: (context) => const CustomFilePickerDialog(
                          title: 'Select Destination Folder',
                          allowFiles: false,
                          allowFolders: true,
                          initialDirectory: 'C:\\',
                        ),
                      );
                      if (selectedPath != null) {
                        logger.i('Selected destination path: $selectedPath');
                        setDialogState(() {
                          destinationPath = selectedPath;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: (selectedBrand != null && selectedModel != null && destinationPath != null)
                  ? () async {
                logger.i('Copy all initiated: brand=$selectedBrand, model=$selectedModel, destination=$destinationPath');
                Navigator.pop(context);
                await _copyAllItems(selectedBrand!, selectedModel!, destinationPath!);
              }
                  : null,
              child: const Text('Copy All', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAllItems(String brand, String model, String destinationPath) async {
    if (_contents.isEmpty || !mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const SimpleLoadingDialog(title: 'Validating all items'));

    try {
      List<File> filesToValidate = [];
      for (var entity in _contents) {
        if (entity is File) {
          filesToValidate.add(entity);
        } else if (entity is Directory) {
          filesToValidate.addAll(await _getFilesInDirectory(entity));
        }
      }

      // Validate all files before copying
      final isValid = await _validateFiles(filesToValidate, brand, model);
      if (!isValid) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not match: hash mismatch'), backgroundColor: Colors.red),
        );
        return;
      }

      // Filter files to copy (only those with matching hashes)
      final key = "$brand-$model";
      final filesToCopy = filesToValidate.where((file) {
        final fileName = path.basename(file.path);
        return _softwareHashes[key]?.containsKey(fileName) ?? false;
      }).toList();

      if (filesToCopy.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files match server configuration'), backgroundColor: Colors.red),
        );
        return;
      }

      Navigator.pop(context);
      showDialog(context: context, barrierDismissible: false, builder: (context) => const SimpleLoadingDialog(title: 'Copying all items'));

      final finalDestPath = path.join(destinationPath, brand, model);
      if (!await Directory(finalDestPath).exists()) {
        await Directory(finalDestPath).create(recursive: true);
      }

      for (var file in filesToCopy) {
        await _fileService.copyFileToLocation(
          sourcePath: file.path,
          fileName: path.basename(file.path),
          brand: brand,
          model: model,
          destinationPath: destinationPath,
          softwareHashes: _softwareHashes,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All matching items copied to $finalDestPath'), backgroundColor: Colors.green),
        );
        setState(() {
          _selectedFileForCopy = null;
        });
        await _loadBackupContents();
      }
    } catch (e) {
      logger.e('Copy all failed: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  void _confirmDelete(FileSystemEntity entity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete "${path.basename(entity.path)}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEntity(entity);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => SimpleLoadingDialog(title: 'Deleting ${path.basename(entity.path)}'));

    try {
      if (entity is File) {
        await _fileService.deleteFile(
          'Unknown', // Placeholder; replace with actual brand if available
          'Unknown', // Placeholder; replace with actual model if available
          path.basename(entity.path),
        );
      } else if (entity is Directory) {
        await _fileService.deleteDirectory(
          'Unknown', // Placeholder; replace with actual brand if available
          'Unknown', // Placeholder; replace with actual model if available
          path.basename(entity.path),
        );
      }
      if (mounted) {
        await _loadBackupContents();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted: ${path.basename(entity.path)}'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Software File Management'),
        actions: [
          if (_selectedBackupDir != null)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: () {
                if (_selectedBackupDir!.path.endsWith(':\\') && Platform.isWindows) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select Drive'),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: 300,
                        child: FutureBuilder<List<String>>(
                          future: _getAvailableDrives(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(child: Text('No drives found'));
                            }
                            return ListView.builder(
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                final drive = snapshot.data![index];
                                return ListTile(
                                  leading: Icon(Icons.storage, color: Colors.blue.shade600),
                                  title: Text(drive),
                                  subtitle: Text(_getDriveLabel(drive)),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      _selectedBackupDir = Directory(drive);
                                      _selectedFileForCopy = null;
                                    });
                                    _loadBackupContents();
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
                    ),
                  );
                } else {
                  setState(() {
                    _selectedBackupDir = _selectedBackupDir!.parent;
                    _selectedFileForCopy = null;
                  });
                  _loadBackupContents();
                }
              },
            ),
          if (_selectedBackupDir != null) IconButton(icon: const Icon(Icons.copy_all), onPressed: _showCopyAllDialog),
        ],
      ),
      body: _selectedBackupDir == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.8), Colors.grey.shade100.withOpacity(0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.grey.shade300.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: Lottie.asset('assets/animations/folder_animation.json', width: 160, height: 160, fit: BoxFit.contain, repeat: true),
            ),
            const SizedBox(height: 32),
            Text('Select File or Folder',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.grey.shade800, letterSpacing: 0.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Choose files or folders to view and manage their contents',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _selectFileOrFolder,
                  icon: const Icon(Icons.folder_open, size: 20),
                  label: const Text('Browse Files & Folders'),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => states.contains(WidgetState.hovered) ? const Color(0xFF10B981).withOpacity(0.9) : const Color(0xFF10B981)),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    elevation: WidgetStateProperty.resolveWith<double>((states) => states.contains(WidgetState.hovered) ? 8 : 4),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    shadowColor: MaterialStateProperty.all(Colors.grey.shade300.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _selectBackupFolder,
                  icon: const Icon(Icons.folder, size: 20),
                  label: const Text('Quick Folder Select'),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => states.contains(WidgetState.hovered) ? Colors.blue.shade600.withOpacity(0.9) : Colors.blue.shade600),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    elevation: WidgetStateProperty.resolveWith<double>((states) => states.contains(WidgetState.hovered) ? 8 : 4),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    shadowColor: MaterialStateProperty.all(Colors.grey.shade300.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200, width: 1)),
              child: Text(
                'Browse: Navigate through folders and view files\nQuick Select: Choose folder directly with system picker',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue.shade700, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      )
          : ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Location: ${_selectedBackupDir!.path}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ..._contents.map(_buildBackupItem).toList(),
        ],
      ),
      floatingActionButton: _selectedBackupDir != null ? FloatingActionButton(onPressed: _loadBackupContents, child: const Icon(Icons.refresh)) : null,
    );
  }

  Future<List<String>> _getAvailableDrives() async {
    if (!Platform.isWindows) return [];
    final drives = <String>[];
    for (int i = 65; i <= 90; i++) {
      final driveLetter = String.fromCharCode(i);
      final drivePath = '$driveLetter:\\';
      try {
        final directory = Directory(drivePath);
        if (await directory.exists()) {
          drives.add(drivePath);
        }
      } catch (e) {
        // Skip inaccessible drives
      }
    }
    return drives;
  }

  String _getDriveLabel(String drive) {
    switch (drive.toUpperCase()) {
      case 'A:\\':
        return 'Floppy Disk';
      case 'C:\\':
        return 'Local Disk (C:)';
      case 'D:\\':
        return 'Local Disk (D:)';
      default:
        return 'Drive ${drive.substring(0, 2)}';
    }
  }
}