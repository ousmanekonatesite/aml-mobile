import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class _Release {
  final String tag;
  final String name;
  final String notes;
  final String apkUrl;
  const _Release(this.tag, this.name, this.notes, this.apkUrl);
}

/// Mise à jour depuis l'application : lit la dernière version publiée sur GitHub (Releases),
/// télécharge l'APK avec une barre de progression puis lance l'installation Android.
/// Prérequis : chaque build CI publie une Release avec un fichier .apk (voir flutter.yml)
/// et tous les APK sont signés avec la même clé (sinon Android refuse la mise à jour).
class AppUpdateService {
  static const _latestReleaseUrl =
      'https://api.github.com/repos/idrissjeux1987/aml-mobile/releases/latest';
  static const _channel = MethodChannel('aml_arena/update');
  static bool _startupChecked = false;

  /// Vérification silencieuse au démarrage : n'affiche rien si l'app est à jour ou en cas d'échec.
  static Future<void> checkOnStartup(BuildContext context) async {
    if (_startupChecked) return;
    _startupChecked = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final release = await _fetchLatest();
      if (_compare(_normalize(release.tag), _normalize(info.version)) <= 0) return;
      if (!context.mounted) return;
      await _offerUpdate(context, release, info.version);
    } catch (_) {}
  }

  /// Vérification manuelle (Profil > Mise à jour AML) avec messages explicites.
  static Future<void> checkAndInstall(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final info = await PackageInfo.fromPlatform();
      final release = await _fetchLatest();
      if (_compare(_normalize(release.tag), _normalize(info.version)) <= 0) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('AML Arena est à jour'),
            content: Text('Version installée : ${info.version}\nDernière version : ${release.name}'),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
          ),
        );
        return;
      }
      if (!context.mounted) return;
      await _offerUpdate(context, release, info.version);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  static Future<_Release> _fetchLatest() async {
    final response = await http.get(
      Uri.parse(_latestReleaseUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) {
      throw Exception('Aucune mise à jour n’est publiée pour le moment.');
    }
    if (response.statusCode == 403) {
      throw Exception('Vérification momentanément indisponible. Réessaie dans quelques minutes.');
    }
    if (response.statusCode != 200) {
      throw Exception('Impossible de vérifier la dernière version.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] ?? '').toString().trim();
    final assets = (data['assets'] as List<dynamic>? ?? const []).whereType<Map>().toList();
    final apk = assets.cast<Map?>().firstWhere(
          (a) => a != null && (a['name'] ?? '').toString().toLowerCase().endsWith('.apk'),
          orElse: () => null,
        );
    final apkUrl = (apk?['browser_download_url'] ?? '').toString();
    if (tag.isEmpty || apkUrl.isEmpty) {
      throw Exception('La dernière version ne contient pas encore d’APK.');
    }
    var notes = (data['body'] ?? '').toString().trim();
    if (notes.length > 500) notes = '${notes.substring(0, 500)}…';
    return _Release(tag, (data['name'] ?? tag).toString(), notes, apkUrl);
  }

  static Future<void> _offerUpdate(BuildContext context, _Release release, String current) async {
    final install = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Mise à jour disponible'),
            content: SingleChildScrollView(
              child: Text(
                'Version actuelle : $current\n'
                'Nouvelle version : ${_normalize(release.tag)}'
                '${release.notes.isEmpty ? '' : '\n\n${release.notes}'}',
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Plus tard')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Mettre à jour')),
            ],
          ),
        ) ??
        false;
    if (!install || !context.mounted) return;
    await _downloadAndInstall(context, release);
  }

  static Future<void> _downloadAndInstall(BuildContext context, _Release release) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = ValueNotifier<double?>(null);
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Téléchargement de la mise à jour'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 12),
                Text(value == null ? 'Connexion…' : '${(value * 100).round()} %'),
              ],
            ),
          ),
        ),
      ),
    ));

    void closeProgress() {
      if (dialogOpen) {
        dialogOpen = false;
        if (navigator.canPop()) navigator.pop();
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/aml_arena_update.apk');
      if (await file.exists()) await file.delete();

      final client = http.Client();
      try {
        final response = await client
            .send(http.Request('GET', Uri.parse(release.apkUrl)))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw Exception('Téléchargement impossible (code ${response.statusCode}).');
        }
        final total = response.contentLength ?? 0;
        var received = 0;
        final sink = file.openWrite();
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) progress.value = received / total;
          }
        } finally {
          await sink.close();
        }
      } finally {
        client.close();
      }

      if (await file.length() < 1024 * 1024) {
        throw Exception('Le fichier de mise à jour est invalide. Réessaie plus tard.');
      }
      closeProgress();

      if (!Platform.isAndroid) {
        await launchUrl(Uri.parse(release.apkUrl), mode: LaunchMode.externalApplication);
        return;
      }
      await _channel.invokeMethod<void>('installApk', {'path': file.path});
    } on PlatformException catch (e) {
      closeProgress();
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Installation impossible.')));
    } catch (e) {
      closeProgress();
      messenger.showSnackBar(SnackBar(content: Text(_friendly(e))));
    } finally {
      closeProgress();
      progress.dispose();
    }
  }

  static String _friendly(Object e) {
    if (e is SocketException || e is TimeoutException || e is http.ClientException) {
      return 'Connexion impossible. Vérifie ton Internet et réessaie.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  static String _normalize(String value) =>
      value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

  static int _compare(String a, String b) {
    final av = a.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final bv = b.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final ai = i < av.length ? av[i] : 0;
      final bi = i < bv.length ? bv[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }
}
