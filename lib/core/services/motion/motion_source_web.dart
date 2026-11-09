import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'motion_sample.dart';

/// Web (inclui Safari do iPhone): evento `devicemotion`.
///
/// O `sensors_plus` usa a Generic Sensor API, que o Safari não implementa.
class MotionSource {
  MotionSource._();

  /// iOS 13+ exige `DeviceMotionEvent.requestPermission()` DENTRO do toque do
  /// usuário. Chame esta função como primeira instrução do handler do botão
  /// (antes de qualquer `await`).
  static Future<bool> requestPermission() async {
    try {
      final ctor = globalContext['DeviceMotionEvent'];
      if (ctor == null || ctor.isUndefinedOrNull) return false;
      final ctorObj = ctor as JSObject;
      if (!ctorObj.has('requestPermission')) return true; // Android/desktop
      final result = await (ctorObj.callMethod('requestPermission'.toJS)
              as JSPromise<JSAny?>)
          .toDart;
      return (result as JSString?)?.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static Stream<MotionSample> stream({
    Duration interval = const Duration(milliseconds: 50),
  }) {
    late StreamController<MotionSample> c;
    JSFunction? handler;
    Timer? watchdog;
    var gotValid = false;

    c = StreamController<MotionSample>(
      onListen: () {
        handler = ((web.Event e) {
          final ev = e as web.DeviceMotionEvent;
          final g = ev.accelerationIncludingGravity;
          final u = ev.acceleration;
          final gx = g?.x, gy = g?.y, gz = g?.z;
          if (gx == null || gy == null || gz == null) return; // sem sensor
          gotValid = true;

          // Sem gravidade: usa `acceleration`; se ausente, tira ~9,81 do módulo.
          double ux, uy, uz;
          if (u?.x != null && u?.y != null && u?.z != null) {
            ux = u!.x!;
            uy = u.y!;
            uz = u.z!;
          } else {
            final mag = sqrt(gx * gx + gy * gy + gz * gz);
            final k = mag == 0 ? 0.0 : (mag - 9.81) / mag;
            ux = gx * k;
            uy = gy * k;
            uz = gz * k;
          }

          final r = ev.rotationRate; // graus/s
          final rot = r == null
              ? 0.0
              : sqrt(pow(r.alpha ?? 0, 2) + pow(r.beta ?? 0, 2) + pow(r.gamma ?? 0, 2)) *
                  pi /
                  180;
          c.add(MotionSample(
              x: gx, y: gy, z: gz, ux: ux, uy: uy, uz: uz, rotation: rot));
        }).toJS;
        web.window.addEventListener('devicemotion', handler);

        // Desktop/navegadores sem sensor disparam eventos vazios (ou nenhum).
        watchdog = Timer(const Duration(seconds: 3), () {
          if (!gotValid && !c.isClosed) {
            c.addError(StateError('Este navegador/aparelho não tem acelerômetro.'));
          }
        });
      },
      onCancel: () {
        watchdog?.cancel();
        if (handler != null) {
          web.window.removeEventListener('devicemotion', handler);
        }
      },
    );
    return c.stream;
  }
}
