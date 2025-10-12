class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  String? _sourceFileName;

  void copyFile(String brand, String model, String fileName) {
    _sourceFileName = fileName;
  }

  void cutFile(String brand, String model, String fileName) {
    _sourceFileName = fileName;
  }

  bool get hasData => _sourceFileName != null;

}