import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:path/path.dart' as path;
import 'package:server/services/ClipboardService.dart';
import 'package:server/services/file_service.dart';
import 'package:server/utils/folder_manager.dart';
import '../services/config_service.dart';
import 'LogViewerScreen.dart';

/*
class EnhancedProgressDialog extends StatefulWidget {
  final String title;
  final bool isLargeFile;
  final String? fileName;
  final int? fileSizeBytes;

  const EnhancedProgressDialog({
    required this.title,
    this.isLargeFile = false,
    this.fileName,
    this.fileSizeBytes,
    super.key,
  });

  @override
  State<EnhancedProgressDialog> createState() => _EnhancedProgressDialogState();
}

class _EnhancedProgressDialogState extends State<EnhancedProgressDialog> {
  bool isTransferComplete = false;

  @override
  void initState() {
    super.initState();
    // Simulate transfer completion after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isTransferComplete = true;
        });
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildLottieAnimation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF10B981).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Lottie.asset(
        isTransferComplete
            ? 'assets/animations/success.json'
            : 'assets/animations/file_transfer.json',
        width: 100,
        height: 100,
        fit: BoxFit.contain,
        repeat: !isTransferComplete, // Loop only for transfer animation
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // File info if available
            if (widget.fileName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.fileName!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.fileSizeBytes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(widget.fileSizeBytes!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Lottie Animation
            _buildLottieAnimation(),

            const SizedBox(height: 20),

            // Status text
            Text(
              isTransferComplete
                  ? 'Transfer Complete!'
                  : widget.isLargeFile
                  ? 'Processing large file'
                  : 'Transferring data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isTransferComplete ? const Color(0xFF10B981) : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              isTransferComplete
                  ? 'Your file has been successfully transferred'
                  : 'Please wait while the operation completes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTransferComplete ? 'Success' : 'Operation in progress',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            if (isTransferComplete) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FileManagementScreen extends StatefulWidget {
  final String brand;
  final String modelOrPath; // Changed to support folder paths

  FileManagementScreen({required this.brand, required this.modelOrPath});

  @override
  _FileManagementScreenState createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> with SingleTickerProviderStateMixin {
  final ClipboardService clipboard = ClipboardService();
  final FileService fileService = FileService();
  final ConfigService configService = ConfigService();
  late Future<List<FileSystemEntity>> filesFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    filesFuture = _getFiles();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<FileSystemEntity>> _getFiles() async {
    String basePath;
    if (await Directory(widget.modelOrPath).exists()) {
      // If modelOrPath is a directory path, use it directly
      basePath = widget.modelOrPath;
    } else {
      // Otherwise, treat it as a model name and get the model path
      basePath = await fileService.folderManager.getModelPath(widget.brand, widget.modelOrPath);
    }
    final dir = Directory(basePath);
    return (await dir.list(recursive: false, followLinks: false).toList())
        .where((entity) => !entity.path.endsWith('.sha1')).toList();
  }

  void _uploadFile() async {
    final selectedOption = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Upload Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Upload File'),
                onTap: () {
                  Navigator.pop(context, 'file');
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Upload Folder'),
                onTap: () {
                  Navigator.pop(context, 'folder');
                },
              ),
            ],
          ),
        );
      },
    );

    if (selectedOption == 'file') {
      final fileResult = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withReadStream: true,
      );
      if (fileResult != null && fileResult.files.isNotEmpty) {
        final file = fileResult.files.first;
        if (kDebugMode) {
          print('Selected file path: ${file.path}');
          print('Is directory: ${await File(file.path!).exists() && await Directory(file.path!).exists()}');
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => EnhancedProgressDialog(
            title: 'Uploading ${file.name}',
          ),
        );
        try {
          await fileService.uploadFile(widget.brand, widget.modelOrPath, file).drain();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('File ${file.name} uploaded successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } catch (e) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Upload failed for ${file.path}: ${e.toString()}'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        setState(() {
          filesFuture = _getFiles();
        });
      } else {
        if (kDebugMode) {
          print('No file selected');
        }
      }
    } else if (selectedOption == 'folder') {
      String? selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath != null) {
        final isDirectory = await Directory(selectedPath).exists();
        if (kDebugMode) {
          print('Selected path: $selectedPath');
          print('Is directory: $isDirectory');
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => EnhancedProgressDialog(
            title: 'Uploading folder ${path.basename(selectedPath)}',
          ),
        );
        try {
          await fileService.uploadDirectory(widget.brand, widget.modelOrPath, selectedPath).drain();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Folder ${path.basename(selectedPath)} uploaded successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } catch (e) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Folder upload failed for $selectedPath: ${e.toString()}'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        setState(() {
          filesFuture = _getFiles();
        });
      } else {
        if (kDebugMode) {
          print('No folder selected');
        }
      }
    } else {
      if (kDebugMode) {
        print('No option selected');
      }
    }
  }

  void _deleteFile(String fileName) async {
    if (fileName == FolderManager.modelLogFileName ||
        fileName == FolderManager.logFileName ||
        fileName.endsWith('.sha1')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield, color: Colors.white),
              const SizedBox(width: 8),
              Text(fileName.endsWith('.sha1')
                  ? 'SHA1 files are protected and cannot be deleted directly'
                  : 'Log files are protected and cannot be deleted'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File'),
        content: Text(
            'Are you sure you want to delete "$fileName"? Its associated SHA1 file will also be deleted. On Windows, files will be moved to the Recycle Bin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      try {
        await fileService.deleteFile(widget.brand, widget.modelOrPath, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete, color: Colors.white),
                const SizedBox(width: 8),
                Text('File $fileName deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Deletion failed for $fileName: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      setState(() {
        filesFuture = _getFiles();
      });
    }
  }

  void _viewLogFile(String fileName, File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogViewerScreen(
          fileName: fileName,
          filePath: file.path,
          brand: widget.brand,
          model: widget.modelOrPath,
        ),
      ),
    );
  }

  String _getFileIcon(String fileName) {
    if (fileName == FolderManager.modelLogFileName || fileName == FolderManager.logFileName) {
      return '📋';
    }
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.pdf':
        return '📄';
      case '.doc':
      case '.docx':
        return '📝';
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return '🖼️';
      case '.mp4':
      case '.mov':
      case '.avi':
        return '🎥';
      case '.mp3':
      case '.wav':
        return '🎵';
      case '.zip':
      case '.rar':
      case '.pkg':
        return '📦';
      default:
        return '📄';
    }
  }

  Color _getFileIconColor(String fileName) {
    if (fileName == FolderManager.modelLogFileName || fileName == FolderManager.logFileName) {
      return const Color(0xFF10B981);
    }
    return Colors.orange;
  }

  String _getFileDescription(String fileName) {
    if (fileName == FolderManager.modelLogFileName || fileName == FolderManager.logFileName) {
      return 'Protected log file';
    }
    return 'Tap for operations (SHA1 protected)';
  }

  void _showFileOperationsDialog(String fileName) async {
    if (fileName == FolderManager.modelLogFileName ||
        fileName == FolderManager.logFileName ||
        fileName.endsWith('.sha1')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield, color: Colors.white),
              const SizedBox(width: 8),
              Text(fileName.endsWith('.sha1')
                  ? 'SHA1 files cannot be copied or moved directly'
                  : 'Log files cannot be copied or moved'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final folderManager = FolderManager();
    final brands = await folderManager.getBrands();
    final Map<String, List<String>> brandModelsMap = {};
    for (final brand in brands) {
      final models = await configService.getModels(brand);
      brandModelsMap[brand] = models;
    }
    String operationType = 'copy';
    String selectedBrand = widget.brand;
    String selectedModel = brandModelsMap[widget.brand]?.isNotEmpty == true ? brandModelsMap[widget.brand]!.first : '';
    String newFileName = fileName;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'File Operations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Operation will include SHA1 integrity verification',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: operationType,
                    items: const [
                      DropdownMenuItem(value: 'copy', child: Text('Copy')),
                      DropdownMenuItem(value: 'move', child: Text('Move')),
                    ],
                    onChanged: (value) => setState(() => operationType = value!),
                    decoration: InputDecoration(
                      labelText: 'Operation',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBrand,
                    items: brands.map((brand) {
                      return DropdownMenuItem(value: brand, child: Text(brand));
                    }).toList(),
                    onChanged: (brand) {
                      if (brand != null) {
                        setState(() {
                          selectedBrand = brand;
                          selectedModel = brandModelsMap[brand]?.isNotEmpty == true ? brandModelsMap[brand]!.first : '';
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Destination Brand',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedModel.isNotEmpty ? selectedModel : null,
                    items: (brandModelsMap[selectedBrand] ?? [])
                        .map((model) => DropdownMenuItem(value: model, child: Text(model)))
                        .toList(),
                    onChanged: (model) {
                      if (model != null) setState(() => selectedModel = model);
                    },
                    decoration: InputDecoration(
                      labelText: 'Destination Model',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'New file name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) => newFileName = value,
                    controller: TextEditingController(text: fileName),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (newFileName.isEmpty || selectedModel.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please provide a file name and select a model.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => EnhancedProgressDialog(
                                title: '${operationType == 'copy' ? 'Copying' : 'Moving'} $fileName',
                              ),
                            );
                            try {
                              if (operationType == 'copy') {
                                await fileService.copyFile(
                                  widget.brand,
                                  widget.modelOrPath,
                                  fileName,
                                  selectedBrand,
                                  selectedModel,
                                  newFileName,
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.copy, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text('File $newFileName copied successfully'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              } else {
                                await fileService.moveFile(
                                  widget.brand,
                                  widget.modelOrPath,
                                  fileName,
                                  selectedBrand,
                                  selectedModel,
                                  newFileName,
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.drive_file_move, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text('File $newFileName moved successfully'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                              setState(() {
                                filesFuture = _getFiles();
                              });
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                          '${operationType == 'copy' ? 'Copy' : 'Move'} failed for $fileName: ${e.toString()}'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Execute'),
                        ),
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

  void _copyModelFolder() async {
    final shouldCopy = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Copy Model Folder'),
        content: Text(
            'Are you sure you want to copy the "${widget.brand}/${widget.modelOrPath}" folder? All files and their SHA1 verifications will be copied.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    if (shouldCopy == true) {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => EnhancedProgressDialog(title: 'Copying ${widget.modelOrPath} folder'),
        );
        try {
          await fileService.copyModelFolder(
            widget.brand,
            widget.modelOrPath,
            result,
          );
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.copy, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Folder ${widget.brand}/${widget.modelOrPath} copied to $result'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } catch (e) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Copy failed for ${widget.modelOrPath} folder: ${e.toString()}'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyModelFolder,
            tooltip: 'Copy Model Folder',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate back to the parent directory or model list
                      final parentDir = Directory(widget.modelOrPath).parent.path;
                      if (parentDir != widget.modelOrPath) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileManagementScreen(
                              brand: widget.brand,
                              modelOrPath: parentDir,
                            ),
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path.basename(widget.modelOrPath),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          '${widget.brand} files and folders (SHA1 protected)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: FutureBuilder<List<FileSystemEntity>>(
                  future: filesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(Icons.upload_file, size: 48, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No files or folders yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload your first file or folder to get started',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    }
                    final entities = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: entities.length,
                      itemBuilder: (context, index) {
                        final entity = entities[index];
                        final entityName = path.basename(entity.path);
                        final isDirectory = FileSystemEntity.typeSync(entity.path) == FileSystemEntityType.directory;
                        final isLogFile = entityName == FolderManager.modelLogFileName || entityName == FolderManager.logFileName;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: isLogFile
                                  ? () => _viewLogFile(entityName, entity as File)
                                  : isDirectory
                                  ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FileManagementScreen(
                                      brand: widget.brand,
                                      modelOrPath: entity.path,
                                    ),
                                  ),
                                );
                              }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isLogFile || isDirectory ? const Color(0xFF10B981).withOpacity(0.3) : Colors.grey.shade200,
                                    width: isLogFile || isDirectory ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  color: (isLogFile || isDirectory) ? const Color(0xFF10B981).withOpacity(0.05) : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getFileIconColor(entityName).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: isDirectory
                                          ? const Icon(Icons.folder, color: Colors.orange, size: 24)
                                          : isLogFile
                                          ? Icon(Icons.shield, color: _getFileIconColor(entityName), size: 24)
                                          : Text(_getFileIcon(entityName), style: const TextStyle(fontSize: 24)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  entityName,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade900,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isLogFile || isDirectory)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    isDirectory ? 'FOLDER' : 'PROTECTED',
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isDirectory
                                                ? 'Tap to view contents'
                                                : _getFileDescription(entityName),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isDirectory || isLogFile ? const Color(0xFF10B981) : Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isLogFile)
                                      Icon(Icons.visibility, color: const Color(0xFF10B981), size: 20)
                                    else if (isDirectory)
                                      Icon(Icons.folder_open, color: Colors.orange, size: 20)
                                    else
                                      PopupMenuButton(
                                        itemBuilder: (context) => [
                                          PopupMenuItem(child: const Text('Copy/Move'), value: 'operation'),
                                          PopupMenuItem(child: const Text('Delete'), value: 'delete'),
                                        ],
                                        onSelected: (value) {
                                          if (value == 'operation') {
                                            _showFileOperationsDialog(entityName);
                                          } else if (value == 'delete') {
                                            _deleteFile(entityName);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.more_vert, size: 20),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (clipboard.hasData)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => EnhancedProgressDialog(title: 'Pasting file'),
                  );
                  try {
                    await clipboard.pasteFile(widget.brand, widget.modelOrPath);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.paste, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('File pasted successfully'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Paste failed: ${e.toString()}'),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                  setState(() {
                    filesFuture = _getFiles();
                  });
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.paste, color: Colors.white),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _uploadFile,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.upload, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}*/
