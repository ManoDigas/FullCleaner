import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'models/android_app_info.dart';
import 'models/cleanup_entry.dart';
import 'services/android_app_service.dart';
import 'services/windows_cleanup_service.dart';

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

class FullCleanerHome extends StatefulWidget {
  const FullCleanerHome({super.key});

  @override
  State<FullCleanerHome> createState() => _FullCleanerHomeState();
}

class _FullCleanerHomeState extends State<FullCleanerHome> {
  final WindowsCleanupService _windowsService = WindowsCleanupService();
  final AndroidAppService _androidService = AndroidAppService();
  final List<CleanupEntry> _entries = <CleanupEntry>[];

  List<AndroidAppInfo> _androidApps = <AndroidAppInfo>[];
  bool _busy = false;
  String? _selectedExe;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FullCleaner'),
        actions: <Widget>[
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
      children: <Widget>[
        _warningCard(
          'O FullCleaner mostra tudo antes de apagar. Pastas críticas do Windows são bloqueadas. '
          'Para obter o melhor resultado, desinstale o programa primeiro e depois faça a varredura de resíduos.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
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
        if (_selectedExe != null) ...<Widget>[
          const SizedBox(height: 12),
          SelectableText('Selecionado: $_selectedExe'),
        ],
        if (_busy) ...<Widget>[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
        ],
        if (_status.isNotEmpty) ...<Widget>[
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
      children: <Widget>[
        _warningCard(
          'No Android, um app comum não pode entrar no armazenamento privado de outro app. '
          'O FullCleaner usa as telas oficiais do Android para limpar dados/desinstalar e só apaga arquivos que você selecionar explicitamente.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _loadAndroidApps,
          icon: const Icon(Icons.refresh),
          label: Text(
            _androidApps.isEmpty
                ? 'Carregar aplicativos'
                : 'Atualizar aplicativos',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickAndroidFiles,
          icon: const Icon(Icons.folder_delete_outlined),
          label: const Text('Selecionar arquivos para apagar'),
        ),
        if (_busy) ...<Widget>[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_status.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(_status),
        ],
        if (_entries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          const Text(
            'Arquivos selecionados',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _buildEntries(),
        ],
        if (_androidApps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 22),
          Text(
            'Aplicativos (${_androidApps.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._androidApps.map(
            (AndroidAppInfo app) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.android)),
                title: Text(app.name),
                subtitle: Text(
                  '${app.packageName}\nVersão ${app.versionName.isEmpty ? 'desconhecida' : app.versionName}',
                ),
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
          children: <Widget>[
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
      children: <Widget>[
        ..._entries.map(
          (CleanupEntry entry) => CheckboxListTile(
            value: entry.selected,
            onChanged: _busy
                ? null
                : (bool? value) {
                    setState(() => entry.selected = value ?? false);
                  },
            title: Text(
              p.basename(entry.path).isEmpty
                  ? entry.path
                  : p.basename(entry.path),
            ),
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
          onPressed: _busy || !_entries.any((CleanupEntry e) => e.selected)
              ? null
              : _confirmAndDelete,
          icon: const Icon(Icons.delete_forever),
          label: Text(
            'Excluir selecionados (${_entries.where((CleanupEntry e) => e.selected).length})',
          ),
        ),
      ],
    );
  }

  Future<void> _pickWindowsExecutable() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione o executável do aplicativo',
      type: FileType.custom,
      allowedExtensions: const <String>['exe'],
      allowMultiple: false,
    );
    final String? path = result?.files.single.path;
    if (path == null) return;

    _selectedExe = path;
    await _scanWindowsTarget(File(path).parent.path, executablePath: path);
  }

  Future<void> _pickWindowsFolder() async {
    final String? path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecione a pasta do aplicativo',
    );
    if (path == null) return;

    _selectedExe = null;
    await _scanWindowsTarget(path);
  }

  Future<void> _scanWindowsTarget(
    String selectedDirectory, {
    String? executablePath,
  }) async {
    setState(() {
      _busy = true;
      _status = 'Analisando locais comuns de resíduos...';
      _entries.clear();
    });

    try {
      final List<CleanupEntry> results = await _windowsService.scanTarget(
        selectedDirectory,
        executablePath: executablePath,
      );
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(results);
        _status = _entries.isEmpty
            ? 'Nenhum resíduo correspondente foi encontrado.'
            : '${_entries.length} item(ns) encontrado(s). Revise antes de excluir.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Falha durante a análise: $error');
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
      final List<AndroidAppInfo> apps = await _androidService.getInstalledApps();
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
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione arquivos para apagar',
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;

    final Iterable<CleanupEntry> additions = result.files
        .where((PlatformFile file) => file.path != null)
        .map(
          (PlatformFile file) => CleanupEntry(
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

  Future<void> _showAndroidAppActions(AndroidAppInfo app) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(app.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(app.packageName),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await _androidService.openSettings(app.packageName);
                  } catch (error) {
                    if (!mounted) return;
                    _showSnack('Não foi possível abrir as configurações: $error');
                  }
                },
                icon: const Icon(Icons.settings),
                label: const Text('Abrir armazenamento/configurações'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  try {
                    final bool started =
                        await _androidService.uninstall(app.packageName);
                    if (!mounted) return;
                    _showSnack(
                      started
                          ? 'Pedido de desinstalação enviado ao Android.'
                          : 'O Android não iniciou a desinstalação.',
                    );
                  } catch (error) {
                    if (!mounted) return;
                    _showSnack('Falha ao iniciar a desinstalação: $error');
                  }
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
    final List<CleanupEntry> selected =
        _entries.where((CleanupEntry entry) => entry.selected).toList();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Você selecionou ${selected.length} item(ns). Esta ação não possui botão de desfazer dentro do FullCleaner. Continuar?',
        ),
        actions: <Widget>[
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
    final List<String> failures = <String>[];

    if (Platform.isWindows) {
      final (int count, List<String> failed) =
          await _windowsService.deleteEntries(selected);
      removed = count;
      failures.addAll(failed);
    } else {
      for (final CleanupEntry entry in selected) {
        try {
          final FileSystemEntityType type =
              FileSystemEntity.typeSync(entry.path, followLinks: false);
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
    }

    if (!mounted) return;
    setState(() {
      _entries.removeWhere(
        (CleanupEntry entry) =>
            selected.contains(entry) && !failures.contains(entry.path),
      );
      _status = failures.isEmpty
          ? '$removed item(ns) removido(s).'
          : '$removed removido(s); ${failures.length} não puderam ser removidos.';
      _busy = false;
    });
  }

  Future<void> _openWindowsAppsSettings() async {
    try {
      await _windowsService.openAppsSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Não foi possível abrir as configurações do Windows.';
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'FullCleaner',
      applicationVersion: '0.1.1',
      children: const <Widget>[
        Text(
          'Ferramenta de limpeza com revisão prévia. Não promete apagar dados fisicamente irrecuperáveis e não contorna proteções do sistema operacional.',
        ),
      ],
    );
  }
}
