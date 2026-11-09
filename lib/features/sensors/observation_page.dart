import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/app_state.dart';
import '../../core/services/location_service.dart';
import '../../core/services/motion/motion_source.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/geo.dart';
import '../../models/sensor_event.dart';
import '../issue_reporting/report_page.dart';

/// Sessão voluntária de observação (acelerômetro + giroscópio + GPS).
/// Impactos são apenas indícios, nunca prova de irregularidade (RB10/RB11).
class ObservationPage extends StatefulWidget {
  const ObservationPage({super.key});

  @override
  State<ObservationPage> createState() => _ObservationPageState();
}

class _ObservationPageState extends State<ObservationPage> {
  static const _thresholds = {'Baixa': 18.0, 'Média': 12.0, 'Alta': 8.0};

  bool _running = false;
  bool _starting = false;
  String _sensitivity = 'Média';
  String? _notice;

  StreamSubscription<MotionSample>? _motionSub;
  StreamSubscription<Position>? _posSub;

  Position? _pos;
  double _gyro = 0;
  final List<double> _mags = [];
  final List<SensorEvent> _events = [];
  DateTime _lastEvent = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _startedAt;
  Timer? _ticker;

  Future<void> _start() async {
    if (_starting) return;
    // 1) Permissão de movimento: PRIMEIRA instrução, ainda dentro do toque
    //    (exigência do iOS). Nada de `await` antes desta linha.
    final permission = MotionSource.requestPermission();
    setState(() {
      _starting = true;
      _notice = null;
    });
    final granted = await permission;
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _starting = false;
        _notice = 'Permissão de movimento negada. No iPhone: Ajustes › Safari › '
            'Movimento e orientação (ou feche e reabra a aba e permita).';
      });
      return;
    }

    // 2) Sensores ligam imediatamente.
    _motionSub = MotionSource.stream().listen(_onSample, onError: (Object e) {
      if (!mounted) return;
      _stop();
      setState(() => _notice = e is StateError
          ? e.message
          : 'Não foi possível acessar os sensores neste aparelho.');
    });
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    setState(() {
      _running = true;
      _starting = false;
      _startedAt = DateTime.now();
    });

    // 3) GPS entra em segundo plano, sem travar a sessão.
    _startLocation();
  }

  Future<void> _startLocation() async {
    try {
      _pos = await LocationService.current();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 3),
      ).listen((p) => _pos = p, onError: (_) {});
    } on LocationFailure catch (e) {
      if (mounted) {
        setState(() => _notice =
            '${e.message} A sessão continua, mas os eventos ficarão sem localização.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Sem GPS: os eventos ficarão sem localização.');
      }
    }
  }

  void _stop() {
    _motionSub?.cancel();
    _posSub?.cancel();
    _ticker?.cancel();
    _motionSub = _posSub = null;
    if (mounted) setState(() => _running = false);
  }

  void _onSample(MotionSample m) {
    final mag = sqrt(m.ux * m.ux + m.uy * m.uy + m.uz * m.uz);
    _gyro = m.rotation;
    _mags.add(mag);
    if (_mags.length > 80) _mags.removeAt(0);

    final now = DateTime.now();
    if (mag >= _thresholds[_sensitivity]! &&
        now.difference(_lastEvent).inSeconds >= 3) {
      _lastEvent = now;
      _registerEvent(mag);
    }
    if (mounted) setState(() {});
  }

  Future<void> _registerEvent(double mag) async {
    final app = AppScope.of(context);
    final p = _pos;
    final near = p == null
        ? null
        : app.issues.nearest(p.latitude, p.longitude, withinMeters: 30);
    final ev = SensorEvent(
      at: DateTime.now(),
      intensity: mag,
      latitude: p?.latitude,
      longitude: p?.longitude,
      nearKnownIssue: near != null,
    );
    setState(() {
      _events.insert(0, ev);
      if (_events.length > 50) _events.removeLast();
    });
    if (near == null && p != null && app.notifyVerification) {
      await NotificationService.show(
        context,
        id: 800,
        title: 'Irregularidade possível',
        body: 'Identificamos um impacto neste trecho. Deseja verificar?',
        channelDescription: 'Alertas de sensores',
      );
    }
  }

  @override
  void dispose() {
    _motionSub?.cancel();
    _posSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String get _elapsed {
    final d = DateTime.now().difference(_startedAt ?? DateTime.now());
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = _mags.isEmpty ? 0.0 : _mags.last;
    return Scaffold(
      appBar: AppBar(title: const Text('Observar trajeto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(_running ? Icons.sensors : Icons.sensors_off,
                      size: 48, color: _running ? cs.primary : cs.outline),
                  const SizedBox(height: 8),
                  Text(
                      _running
                          ? 'Observando… $_elapsed'
                          : 'Sessão de observação desligada',
                      style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _running
                        ? 'Caminhe ou se desloque normalmente. Impactos acima do padrão serão anotados com o local.'
                        : 'Os sensores só coletam dados enquanto você mantiver a sessão ligada. Nada é monitorado em segundo plano.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _running
                        ? FilledButton.tonalIcon(
                            onPressed: _stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Encerrar sessão'))
                        : FilledButton.icon(
                            onPressed: _starting ? null : _start,
                            icon: _starting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.play_arrow),
                            label: Text(_starting ? 'Iniciando…' : 'Iniciar sessão')),
                  ),
                ],
              ),
            ),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_notice!, style: TextStyle(color: cs.error)),
            ),
          const SizedBox(height: 16),
          Text('Sensibilidade', style: text.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                for (final k in _thresholds.keys)
                  ButtonSegment(value: k, label: Text(k)),
              ],
              selected: {_sensitivity},
              onSelectionChanged: (v) => setState(() => _sensitivity = v.first),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movimento em tempo real', style: text.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparkPainter(
                          _mags, cs.primary, _thresholds[_sensitivity]!, cs.error),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Aceleração: ${current.toStringAsFixed(1)} m/s²   ·   Giro: ${_gyro.toStringAsFixed(1)} rad/s',
                      style: text.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Eventos detectados (${_events.length})',
                  style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'Um impacto não significa necessariamente que existe um buraco: depende de como o aparelho está sendo carregado, da velocidade e do piso. Use como indício e confirme visualmente.',
              style: text.bodySmall),
          const SizedBox(height: 8),
          if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Nenhum evento ainda.')),
            ),
          for (final e in _events)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.vibration,
                    color: e.nearKnownIssue ? cs.outline : cs.error),
                title: Text('Impacto de ${e.intensity.toStringAsFixed(1)} m/s²'),
                subtitle: Text([
                  timeAgo(e.at),
                  if (!e.hasLocation)
                    'sem localização'
                  else if (e.nearKnownIssue)
                    'já existe registro próximo'
                  else
                    'sem registro no local',
                ].join(' · ')),
                trailing: e.hasLocation && !e.nearKnownIssue
                    ? TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReportPage(
                                    initialLat: e.latitude,
                                    initialLng: e.longitude))),
                        child: const Text('Verificar'),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double threshold;
  final Color thresholdColor;
  _SparkPainter(this.data, this.color, this.threshold, this.thresholdColor);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = max(threshold * 1.5, data.isEmpty ? 0 : data.reduce(max));
    final ty = size.height - (threshold / maxV) * size.height;
    canvas.drawLine(
        Offset(0, ty),
        Offset(size.width, ty),
        Paint()
          ..color = thresholdColor.withValues(alpha: 0.5)
          ..strokeWidth = 1);
    if (data.length < 2) return;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i / 79 * size.width;
      final y = size.height - (data[i] / maxV) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}
