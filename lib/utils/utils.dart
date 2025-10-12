import 'package:flutter/material.dart';

enum LogType {
  upload(Color(0xFF10B981), Icons.upload, 'UPLOAD'),
  delete(Colors.red, Icons.delete, 'DELETE'),
  copy(Color(0xFF6366F1), Icons.copy, 'COPY'),
  move(Color(0xFF8B5CF6), Icons.open_with, 'MOVE'),
  init(Color(0xFFF59E0B), Icons.settings, 'INITIALIZE'),
  other(Colors.grey, Icons.info, 'EVENT'),
  transfer(Color(0xFF8B5CF6), Icons.open_in_new, 'TRANSFER'),
  backup(Color(0xFF6D28D9), Icons.backup, 'BACKUP');

  const LogType(this.color, this.icon, this.label);
  final Color color;
  final IconData icon;
  final String label;
}

class LogEntry {
  final LogType type;
  final String content;
  final DateTime timestamp;

  LogEntry({
    required this.type,
    required this.content,
    required this.timestamp,
  });
}