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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CopyProgressDialog extends StatefulWidget {
  final String title;
  final Future<bool> Function(void Function(String, int, int) onProgressUpdate) operation;

  const CopyProgressDialog({
    super.key,
    required this.title,
    required this.operation,
  });

  @override
  State<CopyProgressDialog> createState() => _CopyProgressDialogState();
}

class _CopyProgressDialogState extends State<CopyProgressDialog> {
  String _currentFile = '';
  int _currentFileIndex = 0;
  int _totalFiles = 0;
  bool _isValidating = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _startOperation();
  }

  Future<void> _startOperation() async {
    try {
      final success = await widget.operation((String fileName, int current, int total) {
        if (mounted) {
          setState(() {
            _currentFile = fileName;
            _currentFileIndex = current;
            _totalFiles = total;
            _isValidating = fileName.contains('Validating');
          });
        }
      });

      if (mounted) {
        setState(() {
          _isCompleted = true;
        });

        // Wait a moment to show completion then close
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(context).pop(success);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(32),
        width: 400,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isCompleted ? Icons.check_circle_rounded : Icons.copy_rounded,
              size: 48,
              color: _isCompleted ? AppColors.success : AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _isCompleted ? 'Completed!' : widget.title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            if (_isCompleted)
              Text(
                'Operation completed successfully',
                style: GoogleFonts.inter(color: AppColors.success),
              )
            else if (_isValidating)
              Row(
                children: [
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _currentFile,
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              )
            else if (_currentFile.isNotEmpty)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _totalFiles > 0 ? _currentFileIndex / _totalFiles : 0,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentFile,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_currentFileIndex of $_totalFiles',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Preparing...',
                        style: GoogleFonts.inter(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class FileExistsDialog extends StatelessWidget {
  final String fileName;
  final String filePath;

  const FileExistsDialog({
    super.key,
    required this.fileName,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, color: AppColors.warning, size: 24),
                const SizedBox(width: 12),
                Text(
                  'File Already Exists',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'The file "$fileName" already exists at:',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                filePath,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What would you like to do?',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('skip'),
                  child: Text('Skip', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('skipAll'),
                  child: Text('Skip All', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop('replace'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Replace', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Color Palette
class AppColors {
  static const primary = Color(0xFF5B21B6); // Deep purple for vibrancy
  static const secondary = Color(0xFFEC4899); // Pink accent
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF3B82F6);
  static const background = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE5E7EB);
  static const shadow = Color(0x1F000000);
}

class CustomFilePickerDialog extends StatefulWidget {
  final String title;
  final bool allowFiles;
  final bool allowFolders;
  final String? initialDirectory;

  const CustomFilePickerDialog({
    super.key,
    required this.title,
    this.allowFiles = true,
    this.allowFolders = true,
    this.initialDirectory,
  });

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

    setState(() => isLoading = true);

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
          SnackBar(content: Text('Error loading directory: $e'), backgroundColor: AppColors.error),
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

  void _showDriveSelection() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Drive', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
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
                          leading: const Icon(Icons.storage, color: AppColors.primary),
                          title: Text(drive, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _getAvailableDrives() async {
    if (!Platform.isWindows) return [];
    final drives = <String>[];
    for (int i = 65; i <= 90; i++) {
      final drivePath = '${String.fromCharCode(i)}:\\';
      try {
        if (await Directory(drivePath).exists()) drives.add(drivePath);
      } catch (e) {}
    }
    return drives;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.maxFinite,
        height: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            if (currentDirectory != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  currentDirectory!.path,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)))
                  : ListView.builder(
                itemCount: contents.length,
                itemBuilder: (context, index) {
                  final entity = contents[index];
                  final isDirectory = entity is Directory;
                  final name = path.basename(entity.path);
                  return ListTile(
                    leading: Icon(
                      isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                      color: isDirectory ? AppColors.warning : AppColors.info,
                    ),
                    title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onTap: () {
                      if (isDirectory) {
                        _navigateToDirectory(entity);
                      } else if (widget.allowFiles) {
                        setState(() => selectedPath = entity.path);
                      }
                    },
                    hoverColor: AppColors.primary.withOpacity(0.1),
                  ).animate().fadeIn(duration: 200.ms);
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 12),
                if (selectedPath != null)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, selectedPath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Select', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
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

  const SimpleLoadingDialog({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
            const SizedBox(width: 24),
            Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          ],
        ),
      ),
    );
  }
}

class BackupViewerScreen extends StatefulWidget {
  const BackupViewerScreen({super.key});

  @override
  State<BackupViewerScreen> createState() => _BackupViewerScreenState();
}

class _BackupViewerScreenState extends State<BackupViewerScreen> with TickerProviderStateMixin {
  final FileService _fileService = FileService();
  final FolderManager _folderManager = FolderManager();
  final Logger logger = Logger();

  String? _softwareBankPath;
  Map<String, dynamic>? _apiData;
  Set<String> _selectedModels = {};
  String? _currentlyViewed; // Track the currently viewed item (model or file key)
  Map<String, dynamic>? _currentlyViewedData; // Store data for the viewed item
  Map<String, Map<String, String>>? _cachedHashes;
  bool _isOnline = true;
  bool _needsSync = false;
  DateTime? _lastSyncTime;
  String _searchQuery = '';
  String? _statusFilter;
  bool _isSyncing = false;

  TabController? _tabController;
  List<String> _brands = [];
  String? _currentBrand;
  bool _selectAll = false;
  final Map<String, bool> _seriesExpanded = {};

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadApiData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSoftwareBankPath();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('api_data_cache');
    final lastSync = prefs.getInt('last_sync_timestamp');

    if (cachedJson != null) {
      setState(() {
        _apiData = json.decode(cachedJson);
        _lastSyncTime = lastSync != null ? DateTime.fromMillisecondsSinceEpoch(lastSync) : null;
        _invalidateHashCache();
      });
      await _initializeBrands();
    }
  }

  Future<void> _saveCachedData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_data_cache', json.encode(data));
    await prefs.setInt('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
    setState(() => _lastSyncTime = DateTime.now());
  }

  Future<void> _loadSoftwareBankPath() async {
    final prefs = await SharedPreferences.getInstance();
    _softwareBankPath = prefs.getString('software_bank_path');
    if (_softwareBankPath == null && mounted) {
      await _showBankSetupDialog();
    } else {
      setState(() {});
    }
  }

  Future<void> _showBankSetupDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: Text('Setup Required', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: Text('Please select the software bank location to continue.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBankSelectionDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Select Location', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _showBankSelectionDialog() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('software_bank_path', selectedDirectory);
      setState(() {
        _softwareBankPath = selectedDirectory;
        _invalidateHashCache();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Software bank set to: $selectedDirectory'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _loadApiData() async {
    setState(() => _isSyncing = true);
    try {
      final response = await http.get(Uri.parse('https://waltontvrni.com/service-model.php')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveCachedData(data);
        setState(() {
          _apiData = data;
          _isOnline = true;
          _needsSync = false;
          _isSyncing = false;
          _invalidateHashCache();
        });
        await _initializeBrands();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync completed successfully'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        _handleOfflineMode();
      }
    } catch (e) {
      _handleOfflineMode();
    }
  }

  void _handleOfflineMode() {
    setState(() {
      _isOnline = false;
      _isSyncing = false;
      if (_apiData != null) _needsSync = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync: Offline mode'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _initializeBrands() async {
    final brands = await _getBrands();
    setState(() {
      _brands = brands;
      _tabController?.dispose();
      _tabController = TabController(length: brands.length, vsync: this);
      if (brands.isNotEmpty && _tabController != null) {
        _currentBrand = brands[0];
        _tabController!.addListener(() {
          if (!_tabController!.indexIsChanging) {
            setState(() {
              _currentBrand = _brands[_tabController!.index];
              _selectAll = false;
              _currentlyViewed = null;
              _currentlyViewedData = null;
              _seriesExpanded.clear();
            });
          }
        });
      }
    });
  }

  Future<List<String>> _getBrands() async {
    if (_apiData == null) await _loadCachedData();
    return _apiData?['brands']?.cast<String>() ?? [];
  }

  Future<List<String>> _getSeries(String brand) async {
    if (_apiData == null) await _loadCachedData();
    return _apiData?['$brand-series']?.cast<String>() ?? [];
  }

  Future<List<String>> _getModels(String series) async {
    if (_apiData == null) await _loadCachedData();
    return _apiData?['$series-models']?.cast<String>() ?? [];
  }

  Map<String, Map<String, String>> _getSoftwareHashes() {
    if (_cachedHashes != null) return _cachedHashes!;
    if (_apiData == null || _apiData!['software'] == null) return {};

    final software = _apiData!['software'] as Map<String, dynamic>;
    final hashes = <String, Map<String, String>>{};

    software.forEach((brand, brandData) {
      (brandData as Map<String, dynamic>).forEach((series, seriesData) {
        (seriesData as Map<String, dynamic>).forEach((model, fileList) {
          final key = '$brand-$series-$model';
          hashes[key] = {for (var file in fileList as List<dynamic>) file['soft_name'] as String: file['soft_hash'] as String};
        });
      });
    });

    _cachedHashes = hashes;
    return hashes;
  }

  void _invalidateHashCache() {
    _cachedHashes = null;
    setState(() {
      _currentlyViewed = null;
      _currentlyViewedData = null;
    });
  }

  Future<Map<String, dynamic>> _getFileValidationStatus(String brand, String series, String model, String fileName) async {
    final hashes = _getSoftwareHashes();
    final key = '$brand-$series-$model';
    final modelHashes = hashes[key];

    String filePath;
    if (_softwareBankPath != null) {
      filePath = path.join(_softwareBankPath!, brand, series, model, fileName);
    } else {
      filePath = path.join(await _folderManager.getModelPath(brand, model), fileName);
    }

    final file = File(filePath);
    final fileExists = await file.exists();

    DateTime? createdTime;
    int? fileSize;
    if (fileExists) {
      try {
        final stat = await file.stat();
        createdTime = stat.modified;
        fileSize = stat.size;
      } catch (e) {
        logger.e('Error getting file stats: $e');
      }
    }

    if (!fileExists) {
      if (modelHashes != null && modelHashes.containsKey(fileName)) {
        return {
          'status': 'MISSING',
          'color': AppColors.warning,
          'icon': Icons.warning_rounded,
          'message': 'File missing from storage (exists in API)',
          'created': null,
          'size': null,
          'hash': modelHashes[fileName],
          'expectedHash': modelHashes[fileName],
        };
      }
      return {
        'status': 'UNKNOWN',
        'color': AppColors.textSecondary,
        'icon': Icons.help_rounded,
        'message': 'File not found',
        'created': null,
        'size': null,
        'hash': null,
        'expectedHash': null,
      };
    }

    if (modelHashes != null && modelHashes.containsKey(fileName)) {
      try {
        final modelDir = Directory(path.dirname(filePath));
        final hashFile = File(path.join(modelDir.path, 'software_hashes.txt'));

        String? storedHash;
        if (await hashFile.exists()) {
          final content = await hashFile.readAsString();
          final lines = content.split('\n');
          for (var line in lines) {
            if (line.trim().isEmpty || line.startsWith('#')) continue;
            final parts = line.split(':');
            if (parts.length == 2 && parts[0].trim() == fileName) {
              storedHash = parts[1].trim();
              break;
            }
          }
        }

        if (storedHash == null) {
          return {
            'status': 'NO_HASH',
            'color': AppColors.warning,
            'icon': Icons.warning_rounded,
            'message': 'Hash not found in local file',
            'created': createdTime,
            'size': fileSize,
            'hash': null,
            'expectedHash': modelHashes[fileName],
          };
        }

        final expectedHash = modelHashes[fileName];
        if (storedHash == expectedHash) {
          return {
            'status': 'VALID',
            'color': AppColors.success,
            'icon': Icons.check_circle_rounded,
            'message': 'Hash matches API',
            'created': createdTime,
            'size': fileSize,
            'hash': storedHash,
            'expectedHash': expectedHash,
          };
        } else {
          return {
            'status': 'UPDATE',
            'color': AppColors.info,
            'icon': Icons.update_rounded,
            'message': 'Hash changed in API (update available)',
            'created': createdTime,
            'size': fileSize,
            'hash': storedHash,
            'expectedHash': expectedHash,
          };
        }
      } catch (e) {
        return {
          'status': 'ERROR',
          'color': AppColors.error,
          'icon': Icons.error_rounded,
          'message': 'Error validating: $e',
          'created': createdTime,
          'size': fileSize,
          'hash': null,
          'expectedHash': modelHashes[fileName],
        };
      }
    } else {
      return {
        'status': 'INVALID',
        'color': AppColors.error,
        'icon': Icons.close_rounded,
        'message': 'File not in API definition',
        'created': createdTime,
        'size': fileSize,
        'hash': null,
        'expectedHash': null,
      };
    }
  }

  Future<void> _importToBank() async {
    if (_softwareBankPath == null) {
      await _showBankSelectionDialog();
      return;
    }

    final selectedPath = await showDialog<String>(  // Changed variable name from 'result' to 'selectedPath'
      context: context,
      builder: (context) => CustomFilePickerDialog(
        title: 'Select File or Folder to Import',
        allowFiles: true,
        allowFolders: true,
      ),
    );

    if (selectedPath != null && mounted) {  // Use 'selectedPath' instead of 'result'
      final value = await _showImportDialog();
      if (value != null && mounted) {
        bool skipAll = false;
        final skippedFiles = <String>[];
        final replacedFiles = <String>[];

        final success = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => CopyProgressDialog(
            title: 'Importing Files',
            operation: (updateProgress) async {
              try {
                final hashes = _getSoftwareHashes();
                final key = '${value['brand']}-${value['series']}-${value['model']}';
                final modelHashes = hashes[key];

                final copyResult = await _fileService.copyFileToLocationWithProgress(  // Changed variable name from 'result' to 'copyResult'
                  sourcePath: selectedPath,  // Use 'selectedPath' instead of 'result'
                  fileName: path.basename(selectedPath),  // Use 'selectedPath' instead of 'result'
                  brand: value['brand']!,
                  series: value['series']!,
                  model: value['model']!,
                  destinationPath: _softwareBankPath!,
                  softwareHashes: modelHashes != null && modelHashes.isNotEmpty ? {key: modelHashes} : null,
                  onProgressUpdate: updateProgress,
                  onFileExists: (fileName, filePath) async {
                    if (skipAll) {
                      return 'skip';
                    }

                    final decision = await showDialog<String>(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => FileExistsDialog(
                        fileName: fileName,
                        filePath: filePath,
                      ),
                    );

                    if (decision == 'skipAll') {
                      skipAll = true;
                    }

                    return decision ?? 'skip';
                  },
                );

                if (copyResult.success) {  // Use 'copyResult' instead of 'result'
                  skippedFiles.addAll(copyResult.skippedFiles);
                  replacedFiles.addAll(copyResult.replacedFiles);
                  return true;
                } else {
                  throw Exception(copyResult.error);
                }
              } catch (e) {
                logger.e('Import failed: $e');
                rethrow;
              }
            },
          ),
        );

        if (success == true && mounted) {
          setState(() {});

          // Show summary of what happened
          String message = 'Import completed successfully';
          if (skippedFiles.isNotEmpty || replacedFiles.isNotEmpty) {
            message += '\n• Skipped: ${skippedFiles.length} files';
            message += '\n• Replaced: ${replacedFiles.length} files';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _exportSelected({bool specificFiles = false, List<String>? files}) async {
    if (_selectedModels.isEmpty && !specificFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No models selected'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => CustomFilePickerDialog(
        title: 'Select Destination Folder',
        allowFiles: false,
        allowFolders: true,
      ),
    );

    if (result == null || !mounted) return;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CopyProgressDialog(
        title: 'Exporting Files',
        operation: (updateProgress) async {
          try {
            if (specificFiles && files != null) {
              await _fileService.copyToExternalWithProgress(
                files: files,
                destinationPath: result,
                onProgressUpdate: updateProgress,
              );
            } else {
              await _fileService.copyToExternalWithProgress(
                models: _selectedModels.toList(),
                destinationPath: result,
                onProgressUpdate: updateProgress,
              );
            }
            return true;
          } catch (e) {
            logger.e('Export failed: $e');
            rethrow;
          }
        },
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${specificFiles ? files!.length : _selectedModels.length} items'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (!specificFiles) setState(() => _selectedModels.clear());
    }
  }



  Future<Map<String, String>?> _showImportDialog() async {
    String? selectedBrand;
    String? selectedSeries;
    String? selectedModel;

    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: AppColors.surface,
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select Destination', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 24),
                  FutureBuilder<List<String>>(
                    future: _getBrands(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary));
                      return DropdownButtonFormField<String>(
                        value: selectedBrand,
                        decoration: InputDecoration(
                          labelText: 'Brand',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                        items: snap.data!.map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.inter()))).toList(),
                        onChanged: (v) => setDialogState(() {
                          selectedBrand = v;
                          selectedSeries = null;
                          selectedModel = null;
                        }),
                      );
                    },
                  ),
                  if (selectedBrand != null) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<List<String>>(
                      future: _getSeries(selectedBrand!),
                      builder: (context, snap) {
                        if (!snap.hasData) return const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary));
                        return DropdownButtonFormField<String>(
                          value: selectedSeries,
                          decoration: InputDecoration(
                            labelText: 'Series',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          items: snap.data!.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter()))).toList(),
                          onChanged: (v) => setDialogState(() {
                            selectedSeries = v;
                            selectedModel = null;
                          }),
                        );
                      },
                    ),
                  ],
                  if (selectedSeries != null) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<List<String>>(
                      future: _getModels(selectedSeries!),
                      builder: (context, snap) {
                        if (!snap.hasData) return const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary));
                        return DropdownButtonFormField<String>(
                          value: selectedModel,
                          decoration: InputDecoration(
                            labelText: 'Model',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          items: snap.data!.map((m) => DropdownMenuItem(value: m, child: Text(m, style: GoogleFonts.inter()))).toList(),
                          onChanged: (v) => setDialogState(() => selectedModel = v),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      if (selectedBrand != null && selectedSeries != null && selectedModel != null)
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, {
                            'brand': selectedBrand!,
                            'series': selectedSeries!,
                            'model': selectedModel!,
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Import', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }



  Future<void> _deleteSelected() async {
    if (_selectedModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No models selected'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: Text('Confirm Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to delete ${_selectedModels.length} selected models?', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SimpleLoadingDialog(title: 'Deleting...'),
    );

    try {
      for (final selected in _selectedModels) {
        final parts = selected.split('-');
        if (parts.length == 3) {
          final dirPath = path.join(_softwareBankPath!, parts[0], parts[1], parts[2]);
          final dir = Directory(dirPath);
          if (await dir.exists()) await dir.delete(recursive: true);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _selectedModels.clear();
          _currentlyViewed = null;
          _currentlyViewedData = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _previewFile(String brand, String series, String model, String fileName) async {
    final filePath = path.join(_softwareBankPath!, brand, series, model, fileName);
    final file = File(filePath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File not found: $fileName'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final content = await file.readAsString();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: AppColors.surface,
            title: Text('File Preview: $fileName', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Text(content, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textPrimary)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to preview file: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _toggleSelectAll(List<String> allKeys) {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedModels.addAll(allKeys);
      } else {
        _selectedModels.removeWhere((key) => allKeys.contains(key));
      }
      if (_currentlyViewed != null && !_selectedModels.contains(_currentlyViewed) && _selectAll) {
        _selectedModels.add(_currentlyViewed!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        title: Row(
          children: [
            Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Text('Software Manager', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary)),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Import File/Folder',
            child: IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
              onPressed: _importToBank,
            ),
          ),
          Tooltip(
            message: 'Export Selected',
            child: IconButton(
              icon: Icon(Icons.upload_file, color: AppColors.info),
              onPressed: _exportSelected,
            ),
          ),
          Tooltip(
            message: 'Delete Selected',
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _deleteSelected,
            ),
          ),
          Tooltip(
            message: _isSyncing ? 'Syncing...' : 'Sync with API',
            child: IconButton(
              icon: Icon(Icons.sync_rounded, color: _isSyncing ? AppColors.textSecondary : _needsSync ? AppColors.warning : AppColors.success),
              onPressed: _isSyncing ? null : _loadApiData,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _brands.isEmpty || _tabController == null
            ? null
            : PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 4,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: _brands.map((brand) => Tab(text: brand)).toList(),
            ),
          ),
        ),
      ),
      body: _brands.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 80, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No brands available', style: GoogleFonts.inter(fontSize: 18, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadApiData,
              icon: const Icon(Icons.refresh),
              label: Text('Refresh', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      )
          : Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: AppColors.background,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _softwareBankPath == null ? AppColors.warning.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _softwareBankPath == null ? Icons.warning_rounded : Icons.folder_rounded,
                          color: _softwareBankPath == null ? AppColors.warning : AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _softwareBankPath == null ? 'Repository Not Set' : 'Repository',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                              ),
                              Text(
                                _softwareBankPath ?? 'Click to configure',
                                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Tooltip(
                          message: 'Configure Repository',
                          child: IconButton(
                            icon: const Icon(Icons.settings, size: 20),
                            onPressed: _showBankSelectionDialog,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectAll,
                          onChanged: (value) {
                            if (_currentBrand != null) {
                              _getAllModelsForBrand(_currentBrand!).then((keys) {
                                _toggleSelectAll(keys);
                              });
                            }
                          },
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        Text('Select All', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                        const Spacer(),
                        DropdownButton<String?>(
                          value: _statusFilter,
                          hint: Text('Filter by Status', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All')),
                            DropdownMenuItem(value: 'VALID', child: Text('Valid', style: GoogleFonts.inter(color: AppColors.success))),
                            DropdownMenuItem(value: 'MISSING', child: Text('Missing', style: GoogleFonts.inter(color: AppColors.warning))),
                            DropdownMenuItem(value: 'UPDATE', child: Text('Update Available', style: GoogleFonts.inter(color: AppColors.info))),
                            DropdownMenuItem(value: 'INVALID', child: Text('Invalid', style: GoogleFonts.inter(color: AppColors.error))),
                          ],
                          onChanged: (value) => setState(() => _statusFilter = value),
                        ),
                        const SizedBox(width: 12),
                        if (_selectedModels.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_selectedModels.length} selected',
                              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search models or files...',
                        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    ),
                  ),
                  Expanded(
                    child: _currentBrand == null
                        ? Center(child: Text('Select a brand', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)))
                        : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getAllFilesForBrand(_currentBrand!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)));
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('No files found', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
                              ],
                            ),
                          );
                        }
                        final items = snapshot.data!;
                        final filteredItems = items.where((item) {
                          final isModel = item['type'] == 'model';
                          final name = isModel ? item['model'].toString().toLowerCase() : item['fileName'].toString().toLowerCase();
                          return name.contains(_searchQuery);
                        }).toList();
                        final groupedBySeries = <String, List<Map<String, dynamic>>>{};
                        for (var item in filteredItems) {
                          final series = item['series'] as String;
                          groupedBySeries[series] = groupedBySeries[series] ?? [];
                          groupedBySeries[series]!.add(item);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: groupedBySeries.keys.length,
                          itemBuilder: (context, index) {
                            final series = groupedBySeries.keys.elementAt(index);
                            final seriesItems = groupedBySeries[series]!;
                            final isExpanded = _seriesExpanded[series] ?? true;
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  title: Text(
                                    series,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                  ),
                                  trailing: Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                    color: AppColors.textSecondary,
                                  ),
                                  onTap: () {
                                    setState(() => _seriesExpanded[series] = !isExpanded);
                                  },
                                ),
                                if (isExpanded)
                                  ...seriesItems.map((item) {
                                    final key = '${item['brand']}-${item['series']}-${item['model']}';
                                    final isModel = item['type'] == 'model';
                                    final isSelected = _selectedModels.contains(key);
                                    if (isModel) {
                                      return Container(
                                        margin: EdgeInsets.only(bottom: 8, top: index == 0 ? 0 : 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2)),
                                          ],
                                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                                        ),
                                        child: ListTile(
                                          leading: Checkbox(
                                            value: isSelected,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedModels.add(key);
                                                } else {
                                                  _selectedModels.remove(key);
                                                }
                                              });
                                            },
                                            activeColor: AppColors.primary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          title: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.devices, color: Colors.white, size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  item['model'],
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Text(
                                            '${item['series']} • ${item['fileCount']} files',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _currentlyViewed = key;
                                              _currentlyViewedData = item;
                                            });
                                          },
                                          hoverColor: AppColors.primary.withOpacity(0.1),
                                        ),
                                      ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05);
                                    } else {
                                      final fileKey = '$key-${item['fileName']}';
                                      return FutureBuilder<Map<String, dynamic>>(
                                        future: _getFileValidationStatus(item['brand'] as String, item['series'] as String, item['model'] as String, item['fileName'] as String),
                                        builder: (context, validationSnapshot) {
                                          Color statusColor = AppColors.textSecondary;
                                          IconData statusIcon = Icons.help_rounded;
                                          String statusText = 'Checking...';
                                          if (validationSnapshot.hasData) {
                                            final validation = validationSnapshot.data!;
                                            statusColor = validation['color'] as Color;
                                            statusIcon = validation['icon'] as IconData;
                                            statusText = validation['status'] as String;
                                            if (_statusFilter != null && _statusFilter != statusText) return Container();
                                          }
                                          return Container(
                                            margin: const EdgeInsets.only(left: 16, bottom: 8),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2)),
                                              ],
                                              border: Border.all(color: statusColor.withOpacity(0.3)),
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              leading: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(Icons.insert_drive_file_rounded, color: statusColor, size: 18),
                                              ),
                                              title: Text(
                                                item['fileName'] as String,
                                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Tooltip(
                                                    message: 'Preview File',
                                                    child: IconButton(
                                                      icon: Icon(Icons.visibility, color: AppColors.info, size: 18),
                                                      onPressed: () => _previewFile(item['brand'], item['series'], item['model'], item['fileName']),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(statusIcon, color: statusColor, size: 14),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          statusText,
                                                          style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  _currentlyViewed = fileKey;
                                                  _currentlyViewedData = {...item, 'validation': validationSnapshot.data};
                                                });
                                              },
                                              onLongPress: () {
                                                _exportSelected(specificFiles: true, files: [fileKey]);
                                              },
                                              hoverColor: AppColors.primary.withOpacity(0.1),
                                            ),
                                          ).animate().fadeIn(duration: 200.ms);
                                        },
                                      );
                                    }
                                  }).toList(),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, color: AppColors.border),
          Expanded(
            flex: 2,
            child: Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.1), AppColors.secondary.withOpacity(0.05)]),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.info_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text('Information Panel', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _currentlyViewed == null
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'Tap a model or file to view details',
                            style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                        : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_currentlyViewedData?['type'] == 'model') ...[
                          _buildInfoCard('Model', _currentlyViewedData!['model'] as String, Icons.devices, AppColors.primary),
                          const SizedBox(height: 12),

                          _buildInfoCard('Series', _currentlyViewedData!['series'] as String, Icons.category, AppColors.info),
                          const SizedBox(height: 12),

                          ExpansionTile(
                            initiallyExpanded: true,
                            title: Text('Files', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                            childrenPadding: const EdgeInsets.all(16),
                            backgroundColor: AppColors.background,
                            collapsedBackgroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            children: [
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _getModelFilesWithInfo(
                                    _currentlyViewedData!['brand'] as String, _currentlyViewedData!['series'] as String, _currentlyViewedData!['model'] as String),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    return _buildDetailRow('Files', 'No files found');
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: snapshot.data!.map((fileInfo) {
                                      final fileName = fileInfo['fileName'] as String;
                                      final validation = fileInfo['validation'] as Map<String, dynamic>;
                                      final statusColor = validation['color'] as Color;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4)],
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.insert_drive_file_rounded, size: 14, color: statusColor),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    fileName,
                                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.visibility, size: 18, color: AppColors.info),
                                                  onPressed: () => _previewFile(_currentlyViewedData!['brand'], _currentlyViewedData!['series'], _currentlyViewedData!['model'], fileName),
                                                  tooltip: 'Preview File',
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (validation['created'] != null)
                                              _buildInfoRow('Created', _formatDateTime(validation['created'] as DateTime), Icons.access_time),
                                            if (validation['size'] != null)
                                              _buildInfoRow('Size', _formatFileSize(validation['size'] as int), Icons.storage),
                                            if (validation['hash'] != null)
                                              _buildInfoRow('CRC32', validation['hash'] as String, Icons.fingerprint),
                                            if (validation['expectedHash'] != null && validation['hash'] != validation['expectedHash'])
                                              _buildInfoRow('Expected', validation['expectedHash'] as String, Icons.cloud),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                validation['message'] as String,
                                                style: GoogleFonts.inter(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildInfoCard('File', _currentlyViewedData!['fileName'] as String, Icons.insert_drive_file_rounded,
                              (_currentlyViewedData!['validation'] as Map<String, dynamic>)['color'] as Color),
                          const SizedBox(height: 12),
                          _buildInfoCard('Model', _currentlyViewedData!['model'] as String, Icons.devices, AppColors.primary),
                          const SizedBox(height: 12),
                          _buildInfoCard('Brand', _currentlyViewedData!['brand'] as String, Icons.branding_watermark, AppColors.secondary),
                          const SizedBox(height: 12),
                          _buildInfoCard('Series', _currentlyViewedData!['series'] as String, Icons.category, AppColors.info),
                          const SizedBox(height: 12),
                          ExpansionTile(
                            title: Text('File Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                            childrenPadding: const EdgeInsets.all(16),
                            backgroundColor: AppColors.background,
                            collapsedBackgroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            children: [
                              if (_currentlyViewedData!['validation']['created'] != null)
                                _buildDetailRow('Created', _formatDateTime(_currentlyViewedData!['validation']['created'] as DateTime)),
                              if (_currentlyViewedData!['validation']['size'] != null)
                                _buildDetailRow('Size', _formatFileSize(_currentlyViewedData!['validation']['size'] as int)),
                              if (_currentlyViewedData!['validation']['hash'] != null)
                                _buildDetailRow('CRC32', _currentlyViewedData!['validation']['hash'] as String),
                              if (_currentlyViewedData!['validation']['expectedHash'] != null &&
                                  _currentlyViewedData!['validation']['hash'] != _currentlyViewedData!['validation']['expectedHash'])
                                _buildDetailRow('Expected', _currentlyViewedData!['validation']['expectedHash'] as String),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (_currentlyViewedData!['validation']['color'] as Color).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _currentlyViewedData!['validation']['message'] as String,
                                  style: GoogleFonts.inter(fontSize: 10, color: _currentlyViewedData!['validation']['color'] as Color, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildInfoCard('Sync Status', _isOnline ? 'Online' : 'Offline', _isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                            _isOnline ? AppColors.success : AppColors.warning),
                        if (_lastSyncTime != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoCard('Last Sync', _formatLastSync(_lastSyncTime!), Icons.access_time_rounded, AppColors.info),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.background, blurRadius: 6, offset: const Offset(0, 2))],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: AppColors.background, blurRadius: 4)],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<List<Map<String, dynamic>>> _getModelFilesWithInfo(String brand, String series, String model) async {
    final files = await _getFilesForModel(brand, series, model);
    final filesWithInfo = <Map<String, dynamic>>[];

    for (final fileName in files) {
      final validation = await _getFileValidationStatus(brand, series, model, fileName);
      filesWithInfo.add({'fileName': fileName, 'validation': validation});
    }

    return filesWithInfo;
  }

  Future<List<Map<String, dynamic>>> _getAllFilesForBrand(String brand) async {
    final seriesList = await _getSeries(brand);
    final allItems = <Map<String, dynamic>>[];

    for (final series in seriesList) {
      final models = await _getModels(series);
      for (final model in models) {
        final fileCount = await _getFileCount(brand, series, model);
        allItems.add({'type': 'model', 'brand': brand, 'series': series, 'model': model, 'fileCount': fileCount});
        final files = await _getFilesForModel(brand, series, model);
        for (final fileName in files) {
          allItems.add({'type': 'file', 'brand': brand, 'series': series, 'model': model, 'fileName': fileName});
        }
      }
    }

    return allItems;
  }

  Future<List<String>> _getAllModelsForBrand(String brand) async {
    final seriesList = await _getSeries(brand);
    final allKeys = <String>[];

    for (final series in seriesList) {
      final models = await _getModels(series);
      for (final model in models) {
        allKeys.add('$brand-$series-$model');
      }
    }

    return allKeys;
  }

  Future<List<String>> _getFilesForModel(String brand, String series, String model) async {
    try {
      String modelPath;
      if (_softwareBankPath != null) {
        modelPath = path.join(_softwareBankPath!, brand, series, model);
      } else {
        modelPath = await _folderManager.getModelPath(brand, model);
      }

      final dir = Directory(modelPath);
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        final files = entities
            .where((e) => e is File && !path.basename(e.path).startsWith('.'))
            .map((e) => path.basename(e.path))
            .where((name) => name != 'model_log.txt' && name != 'software_hashes.txt')
            .toList();
        files.sort();
        return files;
      }
    } catch (e) {
      logger.e('Error getting files for $brand/$series/$model: $e');
    }
    return [];
  }

  Future<int> _getFileCount(String brand, String series, String model) async {
    final files = await _getFilesForModel(brand, series, model);
    return files.length;
  }

  Future<Map<String, String>> _getModelHashes(String brand, String series, String model) async {
    final hashes = _getSoftwareHashes();
    final key = '$brand-$series-$model';
    return hashes[key] ?? {};
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}