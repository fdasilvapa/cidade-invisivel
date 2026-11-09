import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import 'motion_sample.dart';

/// Android/iOS nativos: acelerômetro e giroscópio via `sensors_plus`.
class MotionSource {
  MotionSource._();

  /// No app nativo a permissão de movimento não é necessária.
  static Future<bool> requestPermission() async => true;

  static Stream<MotionSample> stream({
    Duration interval = const Duration(milliseconds: 50),
  }) {
    late StreamController<MotionSample> c;
    StreamSubscription<AccelerometerEvent>? a;
    StreamSubscription<GyroscopeEvent>? g;
    StreamSubscription<UserAccelerometerEvent>? u;
    double x = 0, y = 0, z = 0, rot = 0;

    c = StreamController<MotionSample>(
      onListen: () {
        a = accelerometerEventStream(samplingPeriod: interval).listen((e) {
          x = e.x;
          y = e.y;
          z = e.z;
        }, onError: c.addError);
        g = gyroscopeEventStream(samplingPeriod: interval).listen(
            (e) => rot = sqrt(e.x * e.x + e.y * e.y + e.z * e.z),
            onError: (_) {});
        u = userAccelerometerEventStream(samplingPeriod: interval).listen(
            (e) => c.add(MotionSample(
                x: x, y: y, z: z, ux: e.x, uy: e.y, uz: e.z, rotation: rot)),
            onError: c.addError);
      },
      onCancel: () async {
        await a?.cancel();
        await g?.cancel();
        await u?.cancel();
      },
    );
    return c.stream;
  }
}
