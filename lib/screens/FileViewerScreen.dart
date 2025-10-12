
import 'dart:io';

import 'package:flutter/material.dart';

class FileViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const FileViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: FutureBuilder<String>(
        future: File(filePath).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              snapshot.data ?? 'Empty file',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          );
        },
      ),
    );
  }
}