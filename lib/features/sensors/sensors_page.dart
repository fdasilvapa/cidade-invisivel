import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/services/motion/motion_source.dart';

import '../../core/services/notification_service.dart';

class SensorsPage extends StatefulWidget {
  const SensorsPage({super.key});

  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage>
    with SingleTickerProviderStateMixin {
  // Acelerômetro com gravidade
  double _x = 0, _y = 0, _z = 0;
  // Sem gravidade (detecta movimento)
  double _ux = 0, _uy = 0, _uz = 0;

  final List<double> _magnitudeHistory = [];
  static const _maxHistory = 50;

  int _shakeCount = 0;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  StreamSubscription<MotionSample>? _sub;
  bool _active = false;
  String? _error;

  late AnimationController _shakeAnim;
  late Animation<double> _scaleAnim;

  int _notifId = 100;

  @override
  void initState() {
    super.initState();

    _shakeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.4)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_shakeAnim);

    // No iOS (web) a permissão só vale se pedida num toque; nos demais casos
    // iniciamos direto e, se for preciso, mostramos o botão "Ativar sensores".
    _begin();
  }

  /// Chamado também pelo botão (gesto do usuário). O `requestPermission` é a
  /// primeira instrução, antes de qualquer `await`.
  Future<void> _begin() async {
    final permission = MotionSource.requestPermission();
    final granted = await permission;
    if (!mounted) return;
    if (!granted) {
      setState(() => _error = 'Toque em "Ativar sensores" para permitir o acesso ao movimento.');
      return;
    }
    await _sub?.cancel();
    setState(() {
      _error = null;
      _active = true;
    });
    _sub = MotionSource.stream(interval: const Duration(milliseconds: 100))
        .listen(_onSample, onError: (Object e) {
      if (!mounted) return;
      setState(() {
        _active = false;
        _error = e is StateError
            ? e.message
            : 'Não foi possível acessar o acelerômetro.';
      });
    });
  }

  void _onSample(MotionSample m) {
    if (!mounted) return;
    final mag = sqrt(m.x * m.x + m.y * m.y + m.z * m.z);
    final umag = sqrt(m.ux * m.ux + m.uy * m.uy + m.uz * m.uz);
    setState(() {
      _x = m.x;
      _y = m.y;
      _z = m.z;
      _ux = m.ux;
      _uy = m.uy;
      _uz = m.uz;
      _magnitudeHistory.add(mag);
      if (_magnitudeHistory.length > _maxHistory) {
        _magnitudeHistory.removeAt(0);
      }
    });
    if (umag > 20.0) {
      final now = DateTime.now();
      if (now.difference(_lastShake).inMilliseconds > 1000) {
        _lastShake = now;
        _onShake();
      }
    }
  }

  Future<void> _onShake() async {
    setState(() => _shakeCount++);
    _shakeAnim.forward(from: 0);

    await NotificationService.show(
      context,
      id: _notifId++,
      title: '📳 Agitação detectada!',
      body: 'Movimento brusco registrado pelo acelerômetro.',
      channelDescription: 'Alertas de sensores',
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _shakeAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acelerômetro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _begin,
                        icon: const Icon(Icons.sensors),
                        label: const Text('Ativar sensores'),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_active)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            if (_error != null || !_active) const SizedBox(height: 12),
            // --- Shake detector ---
            ScaleTransition(
              scale: _scaleAnim,
              child: Card(
                color: _shakeCount > 0
                    ? Colors.orange[50]
                    : Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.vibration, size: 36, color: Colors.orange),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Detector de agitação',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              _shakeCount == 0
                                  ? 'Agite o celular para testar!'
                                  : 'Agitações detectadas: $_shakeCount',
                              style: TextStyle(
                                  color: _shakeCount > 0
                                      ? Colors.orange
                                      : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Valores X Y Z ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Valores brutos (com gravidade)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _AxisRow('X', _x, Colors.red),
                    const SizedBox(height: 8),
                    _AxisRow('Y', _y, Colors.green),
                    const SizedBox(height: 8),
                    _AxisRow('Z', _z, Colors.blue),
                    const SizedBox(height: 12),
                    Text(
                      'Sem gravidade  Ux=${_ux.toStringAsFixed(2)}  Uy=${_uy.toStringAsFixed(2)}  Uz=${_uz.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Gráfico ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Histórico de magnitude',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: CustomPaint(
                        painter: _ChartPainter(_magnitudeHistory),
                        child: Container(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Linha azul = gravidade (9.8 m/s²)',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  final String axis;
  final double value;
  final Color color;

  const _AxisRow(this.axis, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final normalized = ((value + 20) / 40).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(axis,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color)),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: normalized,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(
            '${value.toStringAsFixed(2)} m/s²',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;

  _ChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = 25.0;
    final linePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final refPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, bgPaint);

    // Linha de referência (gravidade 9.8)
    final refY = size.height * (1 - 9.8 / maxVal);
    canvas.drawLine(Offset(0, refY), Offset(size.width, refY), refPaint);

    // Dados
    final step = size.width / (data.length - 1).clamp(1, double.infinity);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height * (1 - (data[i] / maxVal).clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.data != data;
}
