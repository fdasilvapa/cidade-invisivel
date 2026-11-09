import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/issue_category.dart';
import '../../models/urban_issue.dart';
import '../utils/geo.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Registros compartilhados via servidor local (SQLite). Os registros de
/// exemplo (`isDemo`) ficam apenas no aparelho.
class IssueRepository extends ChangeNotifier {
  IssueRepository({http.Client? client, this._baseUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String? _baseUrl;
  String get _base => _baseUrl ?? ApiConfig.baseUrl;

  static const _demoKey = 'demo_issues_v1';
  static const _cacheKey = 'issues_cache_v1';
  static const _deviceKey = 'device_id_v1';
  static const _headers = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  SharedPreferences? _prefs;
  Timer? _poll;
  String _lastRaw = '';

  String deviceId = '';
  bool online = true;
  List<UrbanIssue> _remote = [];
  List<UrbanIssue> _demo = [];
  Set<String> _confirmedByMe = {};
  final Set<String> _demoConfirmed = {};

  List<UrbanIssue> get issues => List.unmodifiable([..._remote, ..._demo]);
  Set<String> get confirmedByMe => {..._confirmedByMe, ..._demoConfirmed};
  bool get hasDemo => _demo.isNotEmpty;
  bool get isEmpty => _remote.isEmpty && _demo.isEmpty;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    var id = _prefs!.getString(_deviceKey);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
      await _prefs!.setString(_deviceKey, id);
    }
    deviceId = id;

    try {
      final raw = _prefs!.getString(_demoKey);
      if (raw != null) {
        _demo = (jsonDecode(raw) as List)
            .map((e) => UrbanIssue.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _demo = [];
    }
    final cached = _prefs!.getString(_cacheKey);
    if (cached != null) _applyRemote(cached, notify: false);

    await refresh();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _client.close();
    super.dispose();
  }

  // ---------- rede ----------
  Future<void> refresh() async {
    try {
      final r = await _client
          .get(Uri.parse('$_base/api/issues?deviceId=$deviceId'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) throw ApiException('HTTP ${r.statusCode}');
      final body = utf8.decode(r.bodyBytes);
      final wasOnline = online;
      online = true;
      if (body != _lastRaw) {
        _applyRemote(body);
        await _prefs?.setString(_cacheKey, body);
      } else if (!wasOnline) {
        notifyListeners();
      }
    } catch (_) {
      if (online) {
        online = false;
        notifyListeners();
      }
    }
  }

  void _applyRemote(String raw, {bool notify = true}) {
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _remote = list.map(UrbanIssue.fromJson).toList();
    _confirmedByMe = {
      for (final j in list)
        if (j['confirmedByMe'] == true) j['id'] as String
    };
    _lastRaw = raw;
    if (notify) notifyListeners();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await _client
          .post(Uri.parse('$_base$path'),
              headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode >= 400) {
        throw ApiException(
            (data is Map ? data['error'] : null)?.toString() ?? 'Erro ${r.statusCode}');
      }
      return data as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (_) {
      online = false;
      notifyListeners();
      throw const ApiException(
          'Sem conexão com o servidor. Verifique a rede e tente de novo.');
    }
  }

  // ---------- ações ----------
  Future<UrbanIssue> add({
    required IssueCategory category,
    required String description,
    required double latitude,
    required double longitude,
    required Severity severity,
    Uint8List? photoBytes,
  }) async {
    final j = await _post('/api/issues', {
      'category': category.name,
      'description': description.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity.name,
      'authorId': deviceId,
      if (photoBytes != null) 'photoBase64': base64Encode(photoBytes),
    });
    await refresh();
    return UrbanIssue.fromJson(j);
  }

  bool _isDemo(String id) => _demo.any((i) => i.id == id);

  Future<void> _demoUpdate(String id, UrbanIssue Function(UrbanIssue) f) async {
    _demo = [for (final i in _demo) i.id == id ? f(i) : i];
    await _prefs?.setString(
        _demoKey, jsonEncode(_demo.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  /// RB06 / RB07: confirmação "ainda existe" (também contesta "resolvido").
  Future<void> confirmStillExists(String id) async {
    if (confirmedByMe.contains(id)) return;
    if (_isDemo(id)) {
      _demoConfirmed.add(id);
      return _demoUpdate(
          id,
          (i) => i.copyWith(
              confirmationCount: i.confirmationCount + 1,
              lastConfirmedAt: DateTime.now(),
              resolved: false));
    }
    await _post('/api/issues/$id/confirm', {'deviceId': deviceId});
    await refresh();
  }

  Future<void> markResolved(String id) async {
    if (_isDemo(id)) return _demoUpdate(id, (i) => i.copyWith(resolved: true));
    await _post('/api/issues/$id/resolve', {'deviceId': deviceId});
    await refresh();
  }

  Future<void> flag(String id) async {
    if (_isDemo(id)) return _demoUpdate(id, (i) => i.copyWith(flagged: true));
    await _post('/api/issues/$id/flag', {'deviceId': deviceId});
    await refresh();
  }

  // ---------- consultas locais ----------
  /// RB05: registros próximos da mesma categoria são possíveis duplicidades.
  List<UrbanIssue> possibleDuplicates(double lat, double lng, IssueCategory c) {
    return issues
        .where((i) =>
            !i.resolved &&
            i.category == c &&
            distanceMeters(lat, lng, i.latitude, i.longitude) < 25)
        .toList();
  }

  UrbanIssue? nearest(double lat, double lng, {double withinMeters = 30}) {
    UrbanIssue? best;
    var bestD = withinMeters;
    for (final i in issues.where((i) => !i.resolved)) {
      final d = distanceMeters(lat, lng, i.latitude, i.longitude);
      if (d <= bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  // ---------- exemplos (somente neste aparelho) ----------
  Future<void> seedDemoNear(double lat, double lng) async {
    if (!isEmpty) return;
    final now = DateTime.now();
    final rnd = Random(7);
    const samples = [
      (IssueCategory.acessibilidade, Severity.high,
          'Rampa de acesso quebrada na esquina', 3),
      (IssueCategory.pavimentacao, Severity.medium,
          'Buraco na calçada, perto do ponto de ônibus', 2),
      (IssueCategory.obstaculos, Severity.medium,
          'Poste ocupando metade da calçada', 1),
      (IssueCategory.sinalizacao, Severity.low,
          'Piso tátil interrompido em frente à farmácia', 0),
      (IssueCategory.desniveis, Severity.high,
          'Degrau alto sem rampa na entrada da praça', 4),
      (IssueCategory.bloqueios, Severity.high,
          'Entulho bloqueando toda a passagem', 2),
    ];
    var n = 0;
    _demo = [
      for (final s in samples)
        UrbanIssue(
          id: 'demo${n++}',
          category: s.$1,
          description: s.$3,
          latitude: lat + (rnd.nextDouble() - .5) * 0.006,
          longitude: lng + (rnd.nextDouble() - .5) * 0.006,
          severity: s.$2,
          createdAt: now.subtract(Duration(days: 3 + n * 4)),
          lastConfirmedAt: now.subtract(Duration(days: n * 2)),
          confirmationCount: s.$4,
          isDemo: true,
        ),
    ];
    await _prefs?.setString(
        _demoKey, jsonEncode(_demo.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> removeDemo() async {
    _demo = [];
    await _prefs?.remove(_demoKey);
    notifyListeners();
  }
}
