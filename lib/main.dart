import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const FullCleanerApp());
}

class FullCleanerApp extends StatelessWidget {
  const FullCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FullCleaner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const FullCleanerHome(),
    );
  }
}

class CleanupEntry {
  CleanupEntry({
    required this.path,
    required this.reason,
    required this.isDirectory,
    this.selected = true,
  });

  final String path;
  final String reason;
  final bool isDirectory;
  bool selected;
}

class FullCleanerHome extends StatefulWidget {
  const FullCleanerHome({super.key});

  @override
  State<FullCleanerHome> createState() => _FullCleanerHomeState();
}

class _FullCleanerHomeState extends State<FullCleanerHome> {
  final List<CleanupEntry> _entries = [];
  List<AppInfo> _androidApps = [];
  bool _busy = false;
  String? _selectedExe;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FullCleaner'),
        actions: [
          IconButton(
            tooltip: 'Sobre',
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout,
          ),
        ],
      ),
      body: Platform.isWindows
          ? _buildWindows()
          : Platform.isAndroid
              ? _buildAndroid()
              : const Center(
                  child: Text('Esta versão suporta Android e Windows.'),
                ),
    );
  }

  Widget _buildWindows() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _warningCard(
          'O FullCleaner mostra tudo antes de apagar. Pastas críticas do Windows são bloqueadas. '
          'Para obter o melhor resultado, desinstale o programa primeiro e depois faça a varredura de resíduos.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _pickWindowsExecutable,
              icon: const Icon(Icons.apps),
              label: const Text('Escolher .exe'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickWindowsFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Escolher pasta'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openWindowsAppsSettings,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Abrir Apps do Windows'),
            ),
          ],
        ),
        if (_selectedExe != null) ...[
          const SizedBox(height: 12),
          SelectableText('Selecionado: $_selectedExe'),
        ],
        if (_busy) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
        ],
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_status),
        ],
        const SizedBox(height: 18),
        _buildEntries(),
      ],
    );
  }

  Widget _buildAndroid() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _warningCard(
          'No Android, um app comum não pode entrar no armazenamento privado de outro app. '
          'O FullCleaner usa as telas oficiais do Android para limpar dados/desinstalar e só apaga arquivos que você selecionar explicitamente.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _loadAndroidApps,
          icon: const Icon(Icons.refresh),
          label: Text(_androidApps.isEmpty ? 'Carregar aplicativos' : 'Atualizar aplicativos'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickAndroidFiles,
          icon: const Icon(Icons.folder_delete_outlined),
          label: const Text('Selecionar arquivos para apagar'),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_status),
        ],
        if (_entries.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Arquivos selecionados', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildEntries(),
        ],
        if (_androidApps.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'Aplicativos (${_androidApps.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._androidApps.map(
            (app) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.android)),
                title: Text(app.name),
                subtitle: Text('${app.packageName}\nVersão ${app.versionName}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAndroidAppActions(app),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _warningCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntries() {
    if (_entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Nenhum item encontrado para revisão.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._entries.map(
          (entry) => CheckboxListTile(
            value: entry.selected,
            onChanged: _busy
                ? null
                : (value) => setState(() => entry.selected = value ?? false),
            title: Text(p.basename(entry.path).isEmpty ? entry.path : p.basename(entry.path)),
            subtitle: Text('${entry.reason}\n${entry.path}'),
            isThreeLine: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _busy || !_entries.any((e) => e.selected) ? null : _confirmAndDelete,
          icon: const Icon(Icons.delete_forever),
          label: Text('Excluir selecionados (${_entries.where((e) => e.selected).length})'),
        ),
      ],
    );
  }

  Future<void> _pickWindowsExecutable() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Selecione o executável do aplicativo',
      type: FileType.custom,
      allowedExtensions: const ['exe'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    _selectedExe = path;
    await _scanWindowsTarget(File(path).parent.path, executablePath: path);
  }

  Future<void> _pickWindowsFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Selecione a pasta do aplicativo',
    );
    if (path == null) return;
    _selectedExe = null;
    await _scanWindowsTarget(path);
  }

  Future<void> _scanWindowsTarget(String selectedDirectory, {String? executablePath}) async {
    setState(() {
      _busy = true;
      _status = 'Analisando locais comuns de resíduos...';
      _entries.clear();
    });

    try {
      final tokens = <String>{
        if (executablePath != null) p.basenameWithoutExtension(executablePath),
        p.basename(p.normalize(selectedDirectory)),
      }
          .map(_cleanToken)
          .where((value) => value.length >= 3 && !_genericNames.contains(value))
          .toSet();

      final found = <String, CleanupEntry>{};

      if (!_isBlockedWindowsPath(selectedDirectory)) {
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
          if (directDir.existsSync() && !_isBlockedWindowsPath(direct)) {
            found[_key(direct)] = CleanupEntry(
              path: direct,
              reason: 'Possível resíduo em ${p.basename(root)}',
              isDirectory: true,
            );
          } else if (directFile.existsSync() && !_isBlockedWindowsPath(direct)) {
            found[_key(direct)] = CleanupEntry(
              path: direct,
              reason: 'Possível resíduo em ${p.basename(root)}',
              isDirectory: false,
            );
          }
        }

        // Varredura apenas do primeiro nível: evita buscas profundas e reduz falsos positivos.
        try {
          await for (final child in directory.list(followLinks: false)) {
            final childName = _cleanToken(p.basename(child.path));
            if (!tokens.contains(childName)) continue;
            if (_isBlockedWindowsPath(child.path)) continue;
            found[_key(child.path)] = CleanupEntry(
              path: child.path,
              reason: 'Nome correspondente encontrado em ${p.basename(root)}',
              isDirectory: child is Directory,
            );
          }
        } on FileSystemException {
          // Alguns diretórios podem exigir privilégios maiores. Eles são ignorados.
        }
      }

      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(found.values);
        _status = _entries.isEmpty
            ? 'Nenhum resíduo correspondente foi encontrado.'
            : '${_entries.length} item(ns) encontrado(s). Revise antes de excluir.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadAndroidApps() async {
    setState(() {
      _busy = true;
      _status = 'Carregando aplicativos instalados...';
    });
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: false,
        withIcon: false,
      );
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _androidApps = apps;
        _status = '${apps.length} aplicativo(s) encontrado(s).';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Não foi possível carregar os aplicativos: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndroidFiles() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Selecione arquivos para apagar',
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;

    final additions = result.files
        .where((file) => file.path != null)
        .map(
          (file) => CleanupEntry(
            path: file.path!,
            reason: 'Arquivo autorizado pelo seletor do Android',
            isDirectory: false,
          ),
        );

    setState(() {
      _entries
        ..clear()
        ..addAll(additions);
      _status = '${_entries.length} arquivo(s) selecionado(s).';
    });
  }

  Future<void> _showAndroidAppActions(AppInfo app) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(app.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(app.packageName),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  InstalledApps.openSettings(app.packageName);
                },
                icon: const Icon(Icons.settings),
                label: const Text('Abrir armazenamento/configurações'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final started = await InstalledApps.uninstallApp(app.packageName);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        started == true
                            ? 'Pedido de desinstalação enviado ao Android.'
                            : 'O Android não iniciou a desinstalação.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Desinstalar pelo Android'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final selected = _entries.where((entry) => entry.selected).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Você selecionou ${selected.length} item(ns). Esta ação não possui botão de desfazer dentro do FullCleaner. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _status = 'Excluindo itens autorizados...';
    });

    var removed = 0;
    final failures = <String>[];

    for (final entry in selected) {
      try {
        if (Platform.isWindows && _isBlockedWindowsPath(entry.path)) {
          failures.add('${entry.path} (protegido)');
          continue;
        }
        final type = FileSystemEntity.typeSync(entry.path, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          await Directory(entry.path).delete(recursive: true);
        } else if (type == FileSystemEntityType.file || type == FileSystemEntityType.link) {
          await File(entry.path).delete();
        }
        removed++;
      } catch (_) {
        failures.add(entry.path);
      }
    }

    if (!mounted) return;
    setState(() {
      _entries.removeWhere((entry) => selected.contains(entry) && !failures.contains(entry.path));
      _status = failures.isEmpty
          ? '$removed item(ns) removido(s).'
          : '$removed removido(s); ${failures.length} não puderam ser removidos.';
      _busy = false;
    });
  }

  Future<void> _openWindowsAppsSettings() async {
    try {
      await Process.start('cmd', ['/c', 'start', '', 'ms-settings:appsfeatures']);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Não foi possível abrir as configurações do Windows.');
    }
  }

  bool _isBlockedWindowsPath(String target) {
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
    if (windowsRoot != null && _isInside(normalized, _key(windowsRoot))) return true;

    final base = _cleanToken(p.basename(normalized));
    if (_genericNames.contains(base)) return true;

    return false;
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

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'FullCleaner',
      applicationVersion: '0.1.0',
      children: const [
        Text(
          'Ferramenta de limpeza com revisão prévia. Não promete apagar dados fisicamente irrecuperáveis e não contorna proteções do sistema operacional.',
        ),
      ],
    );
  }
}
