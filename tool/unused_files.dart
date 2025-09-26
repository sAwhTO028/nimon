// tool/unused_files.dart
import 'dart:io';

final ignoreDirs = RegExp(r'/(gen|build|l10n|.dart_tool|test|ios|android|web|macos|windows|linux)/');
final ignoreExt   = RegExp(r'\.(g|freezed)\.dart$');

void main(List<String> args) {
  final root = Directory('lib');
  if (!root.existsSync()) {
    stderr.writeln('Run from repo root. lib/ not found.');
    exit(1);
  }

  print('Scanning lib directory...');
  
  // 1) Collect all dart files
  final files = <String>[];
  for (final f in root.listSync(recursive: true).whereType<File>()) {
    final p = f.path.replaceAll('\\', '/');
    if (p.endsWith('.dart') && !ignoreDirs.hasMatch(p) && !ignoreExt.hasMatch(p)) {
      files.add(p);
    }
  }
  
  print('Found ${files.length} Dart files');

  // 2) Build import graph
  final allImports = <String>{};

  String norm(String p) => p.replaceAll('\\', '/');

  for (final p in files) {
    try {
      final content = File(p).readAsStringSync();
      
      // Find import statements - simple line by line approach
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
          // Extract path from import/export statement using string manipulation
          final quoteStart = trimmed.indexOf('"');
          final quoteEnd = trimmed.lastIndexOf('"');
          if (quoteStart == -1 || quoteEnd == -1) {
            final singleQuoteStart = trimmed.indexOf("'");
            final singleQuoteEnd = trimmed.lastIndexOf("'");
            if (singleQuoteStart != -1 && singleQuoteEnd != -1) {
              final path = trimmed.substring(singleQuoteStart + 1, singleQuoteEnd);
              String normalizedPath;
              
              if (path.startsWith('package:')) {
                final pkg = path.split(':').last;
                normalizedPath = 'lib/$pkg';
              } else {
                // relative import
                final base = File(p).parent.path;
                final abs = File(norm('$base/$path')).path;
                normalizedPath = norm(abs).replaceAll(RegExp(r'^.*?/lib/'), 'lib/');
              }
              
              if (normalizedPath.endsWith('.dart')) {
                allImports.add(normalizedPath);
              }
            }
          } else {
            final path = trimmed.substring(quoteStart + 1, quoteEnd);
            String normalizedPath;
            
            if (path.startsWith('package:')) {
              final pkg = path.split(':').last;
              normalizedPath = 'lib/$pkg';
            } else {
              // relative import
              final base = File(p).parent.path;
              final abs = File(norm('$base/$path')).path;
              normalizedPath = norm(abs).replaceAll(RegExp(r'^.*?/lib/'), 'lib/');
            }
            
            if (normalizedPath.endsWith('.dart')) {
              allImports.add(normalizedPath);
            }
          }
        }
      }
    } catch (e) {
      print('Error processing $p: $e');
    }
  }

  // 3) Orphans = files not imported by anyone and not main.dart
  final candidates = files.where((p) {
    if (p.endsWith('main.dart')) return false;
    return !allImports.contains(p);
  }).toList()..sort();

  // 4) Print report
  stdout.writeln('--- Unused file candidates (${candidates.length}) ---');
  for (final c in candidates) {
    stdout.writeln(c);
  }
  stdout.writeln('-------------------------------------------');
  stdout.writeln('NOTE: This is static. Router/dynamic usage may not be detected. Review before delete.');
}