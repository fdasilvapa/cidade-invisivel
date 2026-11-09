// Escolhe a implementação: web (devicemotion) ou nativa (sensors_plus).
export 'motion_source_io.dart'
    if (dart.library.js_interop) 'motion_source_web.dart';
export 'motion_sample.dart';
