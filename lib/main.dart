import 'dart:io';

import 'package:flutter/material.dart';

import 'android_cleanup_page.dart';
import 'windows_cleanup_page.dart';

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

class FullCleanerHome extends StatelessWidget {
  const FullCleanerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FullCleaner'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sobre',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAbout(context),
          ),
        ],
      ),
      body: Platform.isAndroid
          ? const AndroidCleanupPage()
          : Platform.isWindows
              ? const WindowsCleanupPage()
              : const Center(
                  child: Text('Esta versão suporta Android e Windows.'),
                ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'FullCleaner',
      applicationVersion: '0.2.0',
      children: const <Widget>[
        Text(
          'Ferramenta de limpeza com revisão prévia. No Android, dados privados são protegidos pelo sistema e são removidos pelo próprio Android durante a desinstalação. Arquivos compartilhados só são apagados após revisão e confirmação do usuário.',
        ),
      ],
    );
  }
}
