import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'models/cleanup_entry.dart';
import 'services/windows_cleanup_service.dart';

class WindowsCleanupPage extends StatefulWidget {
  const WindowsCleanupPage({super.key});

  @override
  State<WindowsCleanupPage> createState() => _WindowsCleanupPageState();
}

class _WindowsCleanupPageState extends State<WindowsCleanupPage> {
  final WindowsCleanupService _service = WindowsCleanupService();
  final List<CleanupEntry> _entries = <CleanupEntry>[];

  bool _busy = false;
  String? _selectedExe;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.shield_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'O FullCleaner mostra tudo antes de apagar. Pastas críticas do Windows são bloqueadas. Para obter o melhor resultado, desinstale o programa primeiro e depois faça a varredura de resíduos.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _busy ? null : _pickExecutable,
              icon: const Icon(Icons.apps),
              label: const Text('Escolher .exe'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Escolher pasta'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openAppsSettings,
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

  Future<void> _pickExecutable() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione o executável do aplicativo',
      type: FileType.custom,
      allowedExtensions: const <String>['exe'],
      allowMultiple: false,
    );
    final String? path = result?.files.single.path;
    if (path == null) return;

    _selectedExe = path;
    await _scan(File(path).parent.path, executablePath: path);
  }

  Future<void> _pickFolder() async {
    final String? path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecione a pasta do aplicativo',
    );
    if (path == null) return;

    _selectedExe = null;
    await _scan(path);
  }

  Future<void> _scan(String directory, {String? executablePath}) async {
    setState(() {
      _busy = true;
      _status = 'Analisando locais comuns de resíduos...';
      _entries.clear();
    });

    try {
      final List<CleanupEntry> results = await _service.scanTarget(
        directory,
        executablePath: executablePath,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(results);
        _status = results.isEmpty
            ? 'Nenhum resíduo correspondente foi encontrado.'
            : '${results.length} item(ns) encontrado(s). Revise antes de excluir.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Falha durante a análise: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

    final (int removed, List<String> failures) =
        await _service.deleteEntries(selected);

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

  Future<void> _openAppsSettings() async {
    try {
      await _service.openAppsSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Não foi possível abrir as configurações do Windows.');
    }
  }
}
