class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  String? _sourceFileName;
  String? _sourceBrand;
  String? _sourceModel;

  void copyFile(String brand, String model, String fileName) {
    _sourceBrand = brand;
    _sourceModel = model;
    _sourceFileName = fileName;
  }

  void cutFile(String brand, String model, String fileName) {
    _sourceBrand = brand;
    _sourceModel = model;
    _sourceFileName = fileName;
  }

  bool get hasData => _sourceFileName != null;

  String? get sourceFileName => _sourceFileName;
  String? get sourceBrand => _sourceBrand;
  String? get sourceModel => _sourceModel;

  void clear() {
    _sourceFileName = null;
    _sourceBrand = null;
    _sourceModel = null;
  }
}