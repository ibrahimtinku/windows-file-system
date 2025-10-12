

import 'file_service.dart';

class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  String? _sourceBrand;
  String? _sourceModel;
  String? _sourceFileName;
  bool _isCut = false;

  void copyFile(String brand, String model, String fileName) {
    _sourceBrand = brand;
    _sourceModel = model;
    _sourceFileName = fileName;
    _isCut = false;
  }

  void cutFile(String brand, String model, String fileName) {
    _sourceBrand = brand;
    _sourceModel = model;
    _sourceFileName = fileName;
    _isCut = true;
  }

  bool get hasData => _sourceFileName != null;

  /*Future<void> pasteFile(String destBrand, String destModel) async {
    if (_sourceFileName == null) return;

    final fileName = _sourceFileName!;
    final isCut = _isCut;

    // Clear clipboard after paste
    _sourceBrand = null;
    _sourceModel = null;
    _sourceFileName = null;

    if (isCut) {
      await FileService().moveFile(
        _sourceBrand!,
        _sourceModel!,
        fileName,
        destBrand,
        destModel,
        fileName, // Keep same file name
      );
    } else {
      await FileService().copyFile(
        _sourceBrand!,
        _sourceModel!,
        fileName,
        destBrand,
        destModel,
        fileName, // Keep same file name
      );
    }
  }*/
}