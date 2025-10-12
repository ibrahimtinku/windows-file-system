import 'package:flutter/material.dart';
import 'package:server/services/file_service.dart';
import 'package:server/utils/folder_manager.dart';
import '../services/config_service.dart';
import 'BackupViewerScreen.dart';
import 'LogViewerScreen.dart';
import 'ModelSelectionScreen.dart';

/*
class BrandSelectionScreen extends StatelessWidget {
  final ConfigService configService = ConfigService();
  final List<IconData> icons = [Icons.tv, Icons.android];
  final List<Color> colors = [
    const Color(0xFF007AFF),
    const Color(0xFF1976D2),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "SOFTWARE MANAGEMENT SYSTEM",
          style: TextStyle(
            color: Colors.blue.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BackupViewerScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.1),
              const Color(0xFF8B5CF6).withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a Brand',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 48),
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: configService.getBrands(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(child: Text('Error loading brands'));
                      }
                      final brands = snapshot.data!;
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: brands.length,
                        separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final brand = brands[index];
                          final icon = icons[index % icons.length];
                          final color = colors[index % colors.length];

                          return Hero(
                            tag: 'brand_$brand',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (context, animation, secondaryAnimation) =>
                                        ModelSelectionScreen(brand: brand),
                                    transitionsBuilder: (context, animation,
                                        secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: animation.drive(
                                          Tween(
                                              begin: const Offset(1.0, 0.0),
                                              end: Offset.zero)
                                              .chain(CurveTween(
                                              curve: Curves.easeInOutCubic)),
                                        ),
                                        child: child,
                                      );
                                    },
                                    transitionDuration:
                                    const Duration(milliseconds: 300),
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Brand icon container
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              color.withOpacity(0.1),
                                              color.withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: color.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          size: 32,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      // Brand info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              brand,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tap to explore models',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // History/Logs button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () async {
                                                final folderManager = FolderManager();
                                                final logFile = await folderManager
                                                    .getBrandLogFile(brand);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        LogViewerScreen(
                                                          fileName:
                                                          FolderManager.logFileName,
                                                          filePath: logFile.path,
                                                          brand: brand,
                                                          model: 'Global Log',
                                                        ),
                                                  ),
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: color.withOpacity(0.1),
                                                  borderRadius:
                                                  BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: color.withOpacity(0.2),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.history,
                                                  size: 20,
                                                  color: color,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Arrow indicator
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey.shade400,
                                          ),
                                        ],
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
              ],
            ),
          ),
        ),
      ),

    );
  }
}*/
