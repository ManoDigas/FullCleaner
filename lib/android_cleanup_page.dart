import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'models/android_app_info.dart';
import 'models/cleanup_entry.dart';
import 'services/android_app_service.dart';

class AndroidCleanupPage extends StatefulWidget {
  const AndroidCleanupPage({super.key});

  @override
  State<AndroidCleanupPage> createState() => _AndroidCleanupPageState();
}

class _AndroidCleanupPageState extends State<AndroidCleanupPage> {
  final AndroidAppService _androidService = AndroidAppService();
  final List<CleanupEntry> _candidates = <CleanupEntry>[];

  List<AndroidAppInfo> _apps = <AndroidAppInfo>[];
  AndroidAppInfo? _selectedApp;
  bool _busy = false;
  String _status = '';
  String? _scannedFolder;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _infoCard(
          'O Android protege os dados privados de cada aplicativo. O FullCleaner consegue revisar arquivos compartilhados que você autorizar, enquanto os dados e caches privados são removidos pelo próprio Android quando a desinstalação é confirmada.',
        ),
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        if (_status.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(_status),
        ],
        const SizedBox(height: 12),
        if (_selectedApp == null) _buildAppList() else _buildSelectedApp(),
      ],
    );
  }

  Widget _buildAppList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Escolha o aplicativo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _busy ? null : _loadApps,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_apps.isEmpty && !_busy)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhum aplicativo carregado.'),
            ),
          ),
        ..._apps.map(
          (AndroidAppInfo app) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.android)),
              title: Text(app.name),
              subtitle: Text(
                '${app.packageName}\nVersão ${app.versionName.isEmpty ? 'desconhecida' : app.versionName}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _selectApp(app),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedApp() {
    final AndroidAppInfo app = _selectedApp!;
    final int checked = _candidates.where((CleanupEntry e) => e.selected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(child: Icon(Icons.android)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(app.name, style: Theme.of(context).textTheme.titleLarge),
                          Text(app.packageName),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Trocar aplicativo',
                      onPressed: _busy ? null : _clearSelection,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _androidService.openSettings(app.packageName),
                  icon: const Icon(Icons.settings),
                  label: const Text('Abrir armazenamento/configurações'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Removido pelo Android', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const CheckboxListTile(
          value: true,
          onChanged: null,
          title: Text('Dados privados e banco de dados'),
          subtitle: Text('Protegidos contra outros apps; são removidos quando a desinstalação é confirmada.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const CheckboxListTile(
          value: true,
          onChanged: null,
          title: Text('Cache privado'),
          subtitle: Text('O Android apaga o cache específico do aplicativo durante a desinstalação.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const CheckboxListTile(
          value: true,
          onChanged: null,
          title: Text('Armazenamento específico do aplicativo'),
          subtitle: Text('Diretórios específicos do app são gerenciados pelo Android e removidos na desinstalação.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const Divider(height: 28),
        Text('Arquivos compartilhados', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Escolha uma pasta como Downloads, Documentos ou uma pasta criada pelo aplicativo. O FullCleaner procura nomes relacionados ao app e deixa tudo desmarcado para você revisar.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _busy ? null : _chooseFolderAndScan,
              icon: const Icon(Icons.folder_open),
              label: const Text('Escolher pasta e procurar'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _addFilesManually,
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Adicionar arquivos manualmente'),
            ),
          ],
        ),
        if (_scannedFolder != null) ...<Widget>[
          const SizedBox(height: 8),
          SelectableText('Pasta analisada: $_scannedFolder'),
        ],
        const SizedBox(height: 10),
        if (_candidates.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Nenhum arquivo compartilhado candidato foi adicionado ainda.'),
            ),
          )
        else
          ..._candidates.map(
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
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _busy ? null : _deleteCheckedAndUninstall,
          icon: const Icon(Icons.delete_forever),
          label: Text(
            checked == 0
                ? 'Desinstalar pelo Android'
                : 'Apagar $checked marcado(s) e desinstalar',
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String text) {
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

  Future<void> _loadApps() async {
    setState(() {
      _busy = true;
      _status = 'Carregando aplicativos instalados...';
    });

    try {
      final List<AndroidAppInfo> apps = await _androidService.getInstalledApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _status = '${apps.length} aplicativo(s) encontrado(s).';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Não foi possível carregar os aplicativos: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectApp(AndroidAppInfo app) {
    setState(() {
      _selectedApp = app;
      _candidates.clear();
      _scannedFolder = null;
      _status = 'Aplicativo selecionado. Agora revise os arquivos compartilhados antes de desinstalar.';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedApp = null;
      _candidates.clear();
      _scannedFolder = null;
      _status = '';
    });
  }

  Future<void> _chooseFolderAndScan() async {
    final AndroidAppInfo? app = _selectedApp;
    if (app == null) return;

    final String? folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Escolha uma pasta para procurar resíduos de ${app.name}',
    );
    if (folder == null) return;

    setState(() {
      _busy = true;
      _status = 'Procurando arquivos relacionados a ${app.name}...';
      _scannedFolder = folder;
    });

    try {
      final List<CleanupEntry> found = await _scanFolder(folder, app);
      if (!mounted) return;
      setState(() {
        _candidates
          ..clear()
          ..addAll(found);
        _status = found.isEmpty
            ? 'Nenhum candidato foi encontrado nessa pasta.'
            : '${found.length} candidato(s) encontrado(s). Eles começam desmarcados; revise antes de apagar.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Não foi possível analisar essa pasta: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<CleanupEntry>> _scanFolder(String rootPath, AndroidAppInfo app) async {
    final Directory root = Directory(rootPath);
    if (!await root.exists()) return <CleanupEntry>[];

    final Set<String> tokens = _tokensFor(app);
    final Map<String, CleanupEntry> found = <String, CleanupEntry>{};
    const int maxCandidates = 250;
    const int maxDepth = 6;

    Future<void> walk(Directory directory, int depth) async {
      if (depth > maxDepth || found.length >= maxCandidates) return;

      try {
        await for (final FileSystemEntity entity in directory.list(followLinks: false)) {
          if (found.length >= maxCandidates) break;

          final String name = p.basename(entity.path);
          final String normalized = _normalize(name);
          final bool matches = tokens.any(
            (String token) => token.length >= 4 && normalized.contains(token),
          );

          if (matches) {
            found[entity.path] = CleanupEntry(
              path: entity.path,
              reason: 'Nome relacionado a ${app.name} / ${app.packageName}',
              isDirectory: entity is Directory,
              selected: false,
            );
            if (entity is Directory) continue;
          }

          if (entity is Directory) {
            await walk(entity, depth + 1);
          }
        }
      } on FileSystemException {
        // Pastas que o Android não autorizou são ignoradas.
      }
    }

    await walk(root, 0);
    return found.values.toList()
      ..sort((CleanupEntry a, CleanupEntry b) => a.path.compareTo(b.path));
  }

  Set<String> _tokensFor(AndroidAppInfo app) {
    final Set<String> tokens = <String>{
      _normalize(app.packageName),
      _normalize(app.packageName.split('.').last),
      _normalize(app.name),
    };

    for (final String word in app.name.split(RegExp(r'\s+'))) {
      final String token = _normalize(word);
      if (token.length >= 4) tokens.add(token);
    }

    return tokens.where((String value) => value.length >= 4).toSet();
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<void> _addFilesManually() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Adicionar arquivos para revisão',
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;

    final List<CleanupEntry> additions = result.files
        .where((PlatformFile file) => file.path != null)
        .map(
          (PlatformFile file) => CleanupEntry(
            path: file.path!,
            reason: 'Arquivo escolhido manualmente',
            isDirectory: false,
            selected: false,
          ),
        )
        .toList();

    setState(() {
      for (final CleanupEntry entry in additions) {
        if (!_candidates.any((CleanupEntry current) => current.path == entry.path)) {
          _candidates.add(entry);
        }
      }
      _status = '${additions.length} arquivo(s) adicionado(s) para revisão.';
    });
  }

  Future<void> _deleteCheckedAndUninstall() async {
    final AndroidAppInfo? app = _selectedApp;
    if (app == null) return;

    final List<CleanupEntry> selected =
        _candidates.where((CleanupEntry entry) => entry.selected).toList();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Remover ${app.name}?'),
        content: Text(
          selected.isEmpty
              ? 'O Android vai abrir a confirmação de desinstalação. Os dados privados e caches específicos do app serão removidos pelo sistema.'
              : 'O FullCleaner vai apagar ${selected.length} item(ns) compartilhado(s) marcados e depois abrir a confirmação de desinstalação do Android. Revise os itens antes de continuar.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _status = 'Removendo itens marcados...';
    });

    final List<String> failures = <String>[];
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
      } catch (_) {
        failures.add(entry.path);
      }
    }

    if (!mounted) return;
    setState(() {
      _candidates.removeWhere(
        (CleanupEntry entry) => selected.contains(entry) && !failures.contains(entry.path),
      );
      _status = failures.isEmpty
          ? 'Itens marcados removidos. Abrindo a confirmação de desinstalação...'
          : '${failures.length} item(ns) não puderam ser apagados. Abrindo a confirmação de desinstalação...';
    });

    try {
      final bool started = await _androidService.uninstall(app.packageName);
      if (!mounted) return;
      setState(() {
        _status = started
            ? 'Confirme a desinstalação na tela do Android.'
            : 'O Android não conseguiu abrir a tela de desinstalação.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Falha ao abrir a desinstalação: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
