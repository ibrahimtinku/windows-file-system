import 'dart:io';

import 'package:flutter/material.dart';
import 'package:server/utils/utils.dart';

class LogViewerScreen extends StatefulWidget {
  final String fileName;
  final String filePath;
  final String brand;
  final String model;

  LogViewerScreen({
    required this.fileName,
    required this.filePath,
    required this.brand,
    required this.model,
  });

  @override
  _LogViewerScreenState createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen>
    with SingleTickerProviderStateMixin {
  late Future<String> logContentFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _autoRefresh = false;

  @override
  void initState() {
    super.initState();
    logContentFuture = _readLogFile();
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

  Future<String> _readLogFile() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.isEmpty ? 'Log file is empty.' : content;
      } else {
        return 'Log file not found.';
      }
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  void _refreshLog() {
    setState(() {
      logContentFuture = _readLogFile();
    });
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });

    if (_autoRefresh) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 8),
              Text('Auto-refresh enabled'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() async {
    while (_autoRefresh && mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (_autoRefresh && mounted) {
        _refreshLog();
      }
    }
  }

  // Update _parseLogEntries in LogViewerScreen
  List<LogEntry> _parseLogEntries(String content) {
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final entries = <LogEntry>[];
    final pattern = RegExp(r'(\w+):\s*(.*?)\s*at\s*(.*)$');

    for (final line in lines) {
      try {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final type = match.group(1)!;
          final details = match.group(2)!;
          final timestamp = DateTime.parse(match.group(3)!);

          LogType logType;
          if (type == 'UPLOAD') {
            logType = LogType.upload;
          } else if (type == 'DELETE') {
            logType = LogType.delete;
          } else if (type == 'COPY') {
            logType = LogType.copy;
          } else if (type == 'MOVE') {
            logType = LogType.move;
          } else if (type == 'TRANSFER') {
            logType = LogType.transfer;
          } else if (type == 'BACKUP') {
            logType = LogType.backup;
          }
          else {
            logType = LogType.init;
          }

          entries.add(LogEntry(
            type: logType,
            content: details,
            timestamp: timestamp,
          ));
        } else if (line.contains('Initialized')) {
          // Handle initialization logs
          final initPattern = RegExp(r'\[(.*?)\]\s*Initialized\s*(.*)$');
          final initMatch = initPattern.firstMatch(line);
          if (initMatch != null) {
            entries.add(LogEntry(
              type: LogType.init,
              content: '${initMatch.group(1)} initialized',
              timestamp: DateTime.parse(initMatch.group(2)!),
            ));
          }
        }
      } catch (e) {
        // Add raw line if parsing fails
        entries.add(LogEntry(
          type: LogType.other,
          content: line.trim(),
          timestamp: DateTime.now(),
        ));
      }
    }

    return entries.reversed.toList(); // Show most recent first
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
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
                        Row(
                          children: [
                            const Icon(
                              Icons.shield,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Log Viewer',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.brand} • ${widget.model}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleAutoRefresh,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _autoRefresh
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _autoRefresh
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Icon(
                            Icons.autorenew,
                            size: 20,
                            color: _autoRefresh
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _refreshLog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF6366F1)),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            size: 20,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: FutureBuilder<String>(
                  future: logContentFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade400,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Error loading log',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final content = snapshot.data ?? '';
                    final logEntries = _parseLogEntries(content);

                    if (logEntries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                Icons.list_alt,
                                size: 48,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No log entries',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Log entries will appear here as operations are performed',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: logEntries.length,
                      itemBuilder: (context, index) {
                        final entry = logEntries[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: entry.type.color.withOpacity(0.3),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: entry.type.color.withOpacity(0.05),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: entry.type.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      entry.type.icon,
                                      color: entry.type.color,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.type.label,
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: entry.type.color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.content,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey.shade700,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    );
  }
}