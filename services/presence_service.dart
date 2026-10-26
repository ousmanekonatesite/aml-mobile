import 'dart:async';
import 'package:flutter/widgets.dart';
import 'supabase_service.dart';

/// Présence réelle : tant que l'application est ouverte, un signal est envoyé toutes les 2 minutes.
/// Un membre est « en ligne » s'il a été vu dans les 5 dernières minutes (compteur d'accueil).
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService _instance = PresenceService._();
  Timer? _timer;
  bool _started = false;
  StreamSubscription? _auth;

  static void start() => _instance._start();

  void _start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      _auth = SupabaseService.client?.auth.onAuthStateChange.listen((event) {
        if (event.session != null) _touch();
      });
    } catch (_) {}
    _resume();
  }

  void _resume() {
    _touch();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _touch());
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _pause();
    }
  }

  Future<void> _touch() async {
    final c = SupabaseService.client;
    if (c == null || c.auth.currentUser == null) return;
    try {
      await c.rpc('aml_touch_presence');
    } catch (_) {}
  }
}
