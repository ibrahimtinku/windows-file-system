import 'package:flutter/material.dart';
import 'package:server/screens/backup_viewer_screen.dart';
import 'package:server/services/clipboard_service.dart';
import 'package:server/utils/folder_manager.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final folderManager = FolderManager();
  await folderManager.initializeAppFolders();

  ClipboardService();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure File Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        fontFamily: 'SF Pro Display',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      home: BackupViewerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}



