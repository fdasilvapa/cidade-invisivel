import 'package:cidade_invisivel/core/services/issue_repository.dart';
import 'package:cidade_invisivel/core/utils/geo.dart';
import 'package:cidade_invisivel/core/utils/relevance.dart';
import 'package:cidade_invisivel/models/issue_category.dart';
import 'package:cidade_invisivel/models/mobility_profile.dart';
import 'package:cidade_invisivel/models/urban_issue.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

UrbanIssue _issue(IssueCategory c, {Severity s = Severity.high, int ageDays = 0}) {
  final d = DateTime.now().subtract(Duration(days: ageDays));
  return UrbanIssue(
      id: 'x',
      category: c,
      description: 'd',
      latitude: 0,
      longitude: 0,
      severity: s,
      createdAt: d,
      lastConfirmedAt: d);
}

void main() {
  test('rampa danificada pesa mais para cadeirante do que para pedestre', () {
    final i = _issue(IssueCategory.acessibilidade);
    expect(priorityScore(i, MobilityProfile.wheelchair),
        greaterThan(priorityScore(i, MobilityProfile.pedestrian)));
  });

  test('problemas antigos sem confirmação perdem prioridade (RB13)', () {
    final novo = _issue(IssueCategory.pavimentacao);
    final velho = _issue(IssueCategory.pavimentacao, ageDays: 120);
    expect(priorityScore(velho, MobilityProfile.pedestrian),
        lessThan(priorityScore(novo, MobilityProfile.pedestrian)));
  });

  test('perfil geral trata todas as categorias igualmente', () {
    final impacts = IssueCategory.values
        .map(MobilityProfile.general.impactOf)
        .toSet();
    expect(impacts.length, 1);
  });

  test('distância haversine ~111 km por grau de latitude', () {
    expect(distanceMeters(0, 0, 1, 0), closeTo(111195, 300));
  });

  test('serialização do registro preserva os campos', () {
    final i = _issue(IssueCategory.desniveis);
    final j = UrbanIssue.fromJson(i.toJson());
    expect(j.category, IssueCategory.desniveis);
    expect(j.severity, Severity.high);
  });

  test('repositório (API): criar, duplicidade, confirmar e contestar', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeApi();
    final repo = IssueRepository(client: fake.client, baseUrl: 'http://x');
    await repo.load();

    final a = await repo.add(
        category: IssueCategory.pavimentacao,
        description: 'buraco',
        latitude: -23.55,
        longitude: -46.63,
        severity: Severity.medium);
    expect(repo.issues, hasLength(1));
    expect(repo.issues.first.mine, isTrue);

    expect(
        repo.possibleDuplicates(-23.55001, -46.63001, IssueCategory.pavimentacao),
        hasLength(1));
    expect(
        repo.possibleDuplicates(-23.55001, -46.63001, IssueCategory.bloqueios),
        isEmpty);

    await repo.markResolved(a.id);
    expect(repo.issues.first.resolved, isTrue);

    await repo.confirmStillExists(a.id); // contesta o "resolvido" (RB07)
    expect(repo.issues.first.resolved, isFalse);
    expect(repo.issues.first.confirmationCount, 1);

    await repo.confirmStillExists(a.id); // mesmo aparelho não conta duas vezes
    expect(repo.issues.first.confirmationCount, 1);
    repo.dispose();
  });

  test('repositório: sem servidor fica offline e add falha com mensagem', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = IssueRepository(
        client: MockClient((_) async => throw Exception('rede')),
        baseUrl: 'http://x');
    await repo.load();
    expect(repo.online, isFalse);
    await expectLater(
        () => repo.add(
            category: IssueCategory.obstaculos,
            description: '',
            latitude: 0,
            longitude: 0,
            severity: Severity.low),
        throwsA(isA<ApiException>()));
    repo.dispose();
  });
}

/// Servidor falso em memória que imita a API de server/server.py.
class _FakeApi {
  final List<Map<String, dynamic>> issues = [];
  final Set<String> confirmed = {};
  late final MockClient client = MockClient(_handle);

  Map<String, dynamic> _view(Map<String, dynamic> i, String device) =>
      {...i, 'confirmedByMe': confirmed.contains('${i['id']}|$device')};

  Future<http.Response> _handle(http.Request r) async {
    final path = r.url.path;
    final device = r.url.queryParameters['deviceId'] ?? '';
    http.Response ok(Object o, [int c = 200]) => http.Response(
        jsonEncode(o), c,
        headers: {'content-type': 'application/json; charset=utf-8'});

    if (r.method == 'GET' && path == '/api/issues') {
      return ok([for (final i in issues) _view(i, device)]);
    }
    final body = r.body.isEmpty ? {} : jsonDecode(r.body) as Map;
    if (r.method == 'POST' && path == '/api/issues') {
      final now = DateTime.now().toUtc().toIso8601String();
      final i = {
        'id': 'id${issues.length}',
        'category': body['category'],
        'description': body['description'],
        'latitude': body['latitude'],
        'longitude': body['longitude'],
        'severity': body['severity'],
        'createdAt': now,
        'lastConfirmedAt': now,
        'confirmationCount': 0,
        'resolved': false,
        'flagged': false,
        'mine': true,
      };
      issues.add(i);
      return ok(_view(i, body['authorId'] as String), 201);
    }
    final m = RegExp(r'^/api/issues/(\w+)/(\w+)$').firstMatch(path);
    if (r.method == 'POST' && m != null) {
      final i = issues.firstWhere((e) => e['id'] == m[1]);
      final dev = body['deviceId'] as String;
      switch (m[2]) {
        case 'confirm':
          if (confirmed.add('${i['id']}|$dev')) {
            i['confirmationCount'] = (i['confirmationCount'] as int) + 1;
            i['resolved'] = false;
          }
        case 'resolve':
          i['resolved'] = true;
        case 'flag':
          i['flagged'] = true;
      }
      return ok(_view(i, dev));
    }
    return ok({'error': 'rota'}, 404);
  }
}
