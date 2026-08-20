import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/cleanup_entry.dart';

class WindowsCleanupService {
  Future<List<CleanupEntry>> scanTarget(
    String selectedDirectory, {
    String? executablePath,
  }) async {
    final tokens = <String>{
      if (executablePath != null) p.basenameWithoutExtension(executablePath),
      p.basename(p.normalize(selectedDirectory)),
    }
        .map(_cleanToken)
        .where((value) => value.length >= 3 && !_genericNames.contains(value))
        .toSet();

    final found = <String, CleanupEntry>{};

    if (!isBlockedPath(selectedDirectory)) {
      found[_key(selectedDirectory)] = CleanupEntry(
        path: selectedDirectory,
        reason: 'Pasta do aplicativo selecionada (opcional)',
        isDirectory: true,
        selected: false,
      );
    }

    final env = Platform.environment;
    final roots = <String>{
      if (env['LOCALAPPDATA'] case final value?) value,
      if (env['APPDATA'] case final value?) value,
      if (env['PROGRAMDATA'] case final value?) value,
      if (env['USERPROFILE'] case final value?) p.join(value, 'AppData', 'LocalLow'),
    };

    for (final root in roots) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;

      for (final token in tokens) {
        final direct = p.join(root, token);
        final directDir = Directory(direct);
        final directFile = File(direct);

        if (directDir.existsSync() && !isBlockedPath(direct)) {
          found[_key(direct)] = CleanupEntry(
            path: direct,
            reason: 'Possível resíduo em ${p.basename(root)}',
            isDirectory: true,
          );
        } else if (directFile.existsSync() && !isBlockedPath(direct)) {
          found[_key(direct)] = CleanupEntry(
            path: direct,
            reason: 'Possível resíduo em ${p.basename(root)}',
            isDirectory: false,
          );
        }
      }

      try {
        await for (final child in directory.list(followLinks: false)) {
          final childName = _cleanToken(p.basename(child.path));
          if (!tokens.contains(childName) || isBlockedPath(child.path)) continue;

          found[_key(child.path)] = CleanupEntry(
            path: child.path,
            reason: 'Nome correspondente encontrado em ${p.basename(root)}',
            isDirectory: child is Directory,
          );
        }
      } on FileSystemException {
        // Diretórios sem permissão são ignorados.
      }
    }

    return found.values.toList();
  }

  Future<(int removed, List<String> failures)> deleteEntries(
    List<CleanupEntry> entries,
  ) async {
    var removed = 0;
    final failures = <String>[];

    for (final entry in entries) {
      try {
        if (isBlockedPath(entry.path)) {
          failures.add(entry.path);
          continue;
        }

        final type = FileSystemEntity.typeSync(entry.path, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          await Directory(entry.path).delete(recursive: true);
        } else if (type == FileSystemEntityType.file ||
            type == FileSystemEntityType.link) {
          await File(entry.path).delete();
        }
        removed++;
      } catch (_) {
        failures.add(entry.path);
      }
    }

    return (removed, failures);
  }

  bool isBlockedPath(String target) {
    if (!Platform.isWindows) return false;

    final normalized = _key(target);
    final env = Platform.environment;
    final exactProtected = <String>{
      if (env['SystemDrive'] case final value?) '$value\\',
      if (env['SystemRoot'] case final value?) value,
      if (env['WINDIR'] case final value?) value,
      if (env['ProgramFiles'] case final value?) value,
      if (env['ProgramFiles(x86)'] case final value?) value,
      if (env['USERPROFILE'] case final value?) value,
      if (env['LOCALAPPDATA'] case final value?) value,
      if (env['APPDATA'] case final value?) value,
      if (env['PROGRAMDATA'] case final value?) value,
    }.map(_key).toSet();

    if (exactProtected.contains(normalized)) return true;

    final windowsRoot = env['SystemRoot'] ?? env['WINDIR'];
    if (windowsRoot != null && _isInside(normalized, _key(windowsRoot))) {
      return true;
    }

    final base = _cleanToken(p.basename(normalized));
    return _genericNames.contains(base);
  }

  Future<void> openAppsSettings() async {
    await Process.start('cmd', ['/c', 'start', '', 'ms-settings:appsfeatures']);
  }

  bool _isInside(String child, String parent) {
    final separator = Platform.pathSeparator;
    return child == parent || child.startsWith('$parent$separator');
  }

  String _key(String value) => p.normalize(p.absolute(value)).toLowerCase();

  String _cleanToken(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._ -]'), '')
      .trim();

  static const Set<String> _genericNames = {
    'app',
    'apps',
    'application',
    'applications',
    'bin',
    'common files',
    'current',
    'data',
    'files',
    'microsoft',
    'program',
    'program files',
    'program files (x86)',
    'programs',
    'system32',
    'windows',
    'windowsapps',
    'x64',
    'x86',
  };
}
