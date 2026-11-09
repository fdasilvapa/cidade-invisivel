import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/app_state.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/relevance.dart';
import '../../models/issue_category.dart';
import '../../models/mobility_profile.dart';
import '../../models/urban_issue.dart';
import '../issue_details/issue_details_sheet.dart';
import '../issue_reporting/report_page.dart';
import '../../shared/widgets/profile_sheet.dart';
import 'alerts_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _defaultCenter = LatLng(-23.5505, -46.6333);

  final _map = MapController();
  Position? _me;
  bool _locating = false;
  String? _locError;
  bool _notifiedNearby = false;

  final Set<IssueCategory> _categories = {};
  bool _showResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  Future<void> _locate({bool moveCamera = true}) async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final pos = await LocationService.current();
      if (!mounted) return;
      setState(() => _me = pos);
      if (moveCamera) _map.move(LatLng(pos.latitude, pos.longitude), 17);
      final app = AppScope.of(context);
      await app.issues.seedDemoNear(pos.latitude, pos.longitude);
      _maybeNotifyNearby(app, pos);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locError = e.message);
    } catch (e) {
      if (mounted) setState(() => _locError = 'Não foi possível obter sua localização.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _maybeNotifyNearby(AppState app, Position pos) {
    if (_notifiedNearby || !app.notifyNearby) return;
    final relevant = _nearbyRelevant(app, pos, 300);
    if (relevant.isEmpty) return;
    _notifiedNearby = true;
    final i = relevant.first;
    NotificationService.show(
      context,
      id: 900,
      title: 'Atenção na sua região',
      body: '${i.category.label}: ${i.description} '
          '(a ${formatDistance(distanceMeters(pos.latitude, pos.longitude, i.latitude, i.longitude))}).',
    );
  }

  List<UrbanIssue> _nearbyRelevant(AppState app, Position pos, double radius) {
    final list = app.issues.issues
        .where((i) =>
            !i.resolved &&
            app.profile.impactOf(i.category) == ImpactLevel.high &&
            distanceMeters(pos.latitude, pos.longitude, i.latitude, i.longitude) <=
                radius)
        .toList()
      ..sort((a, b) =>
          priorityScore(b, app.profile).compareTo(priorityScore(a, app.profile)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.issues,
      builder: (context, _) {
        final profile = app.profile;
        final visible = app.issues.issues
            .where((i) =>
                (_showResolved || !i.resolved) &&
                (_categories.isEmpty || _categories.contains(i.category)))
            .toList()
          ..sort((a, b) =>
              priorityScore(a, profile).compareTo(priorityScore(b, profile)));
        final alerts = _me == null
            ? app.issues.issues
                .where((i) =>
                    !i.resolved &&
                    profile.impactOf(i.category) == ImpactLevel.high)
                .length
            : _nearbyRelevant(app, _me!, 500).length;

        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: const MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'br.com.cidadeinvisivel.cidade_invisivel',
                  ),
                  MarkerLayer(markers: [
                    for (final i in visible) _issueMarker(i, profile),
                    if (_me != null) _meMarker(_me!),
                  ]),
                  const RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution('© colaboradores do OpenStreetMap'),
                    ],
                  ),
                ],
              ),
              _topBar(context, app, alerts),
              if (_locError != null) _locationBanner(),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'locate',
                tooltip: 'Minha localização',
                onPressed: _locating ? null : _locate,
                child: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'report',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReportPage(
                            initialLat: _me?.latitude,
                            initialLng: _me?.longitude))),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Registrar problema'),
              ),
            ],
          ),
        );
      },
    );
  }

  Marker _issueMarker(UrbanIssue i, MobilityProfile profile) {
    final impact = profile.impactOf(i.category);
    final high = impact == ImpactLevel.high && !i.resolved;
    final size = high ? 50.0 : 38.0;
    final color = i.resolved ? Colors.grey : i.category.color;
    return Marker(
      point: LatLng(i.latitude, i.longitude),
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label:
            '${i.category.label}, gravidade ${i.severity.label}, impacto ${impact.label} para ${profile.label}',
        child: GestureDetector(
          onTap: () => showIssueDetails(context, i.id),
          child: Opacity(
            opacity: (impact == ImpactLevel.low && profile != MobilityProfile.general) ||
                    i.resolved
                ? 0.55
                : 1,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: high ? const Color(0xFFFFC107) : Colors.white,
                    width: high ? 4 : 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4)
                ],
              ),
              child: Icon(i.resolved ? Icons.check : i.category.icon,
                  color: Colors.white, size: high ? 26 : 20),
            ),
          ),
        ),
      ),
    );
  }

  Marker _meMarker(Position p) => Marker(
        point: LatLng(p.latitude, p.longitude),
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
          ),
        ),
      );

  Widget _topBar(BuildContext context, AppState app, int alerts) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(28),
                    color: cs.surface,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => showProfileSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(app.profile.icon, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Visão: ${app.profile.label}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  elevation: 3,
                  shape: const CircleBorder(),
                  color: cs.surface,
                  child: IconButton(
                    tooltip: 'Alertas na região',
                    onPressed: () => showAlertsSheet(context, _me),
                    icon: Badge(
                      isLabelVisible: alerts > 0,
                      label: Text('$alerts'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in IssueCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(c.icon,
                            size: 18,
                            color: _categories.contains(c) ? null : c.color),
                        label: Text(c.label),
                        selected: _categories.contains(c),
                        backgroundColor: cs.surface,
                        elevation: 2,
                        onSelected: (v) => setState(
                            () => v ? _categories.add(c) : _categories.remove(c)),
                      ),
                    ),
                  FilterChip(
                    label: const Text('Resolvidos'),
                    selected: _showResolved,
                    backgroundColor: cs.surface,
                    elevation: 2,
                    onSelected: (v) => setState(() => _showResolved = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationBanner() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_locError!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ),
        ),
      ),
    );
  }
}
