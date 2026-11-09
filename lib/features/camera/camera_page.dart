import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String? _capturedPath;
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      // Na web o próprio navegador pede a permissão ao abrir a câmera.
      final granted =
          kIsWeb || (await Permission.camera.request()).isGranted;
      if (!granted) {
        _fail('Permissão de câmera negada. Libere o acesso nas configurações.');
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _fail('Nenhuma câmera encontrada neste aparelho.');
        return;
      }
      // Prefere a câmera traseira (fotografar o problema na rua).
      final cam = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first);
      await _startCamera(cam);
    } on CameraException catch (e) {
      _fail(_friendly(e));
    } catch (e) {
      _fail('Não foi possível abrir a câmera: $e');
    }
  }

  String _friendly(CameraException e) {
    final c = e.code.toLowerCase();
    if (c.contains('denied') || c.contains('permission') || c.contains('notallowed')) {
      return 'Permissão de câmera negada. Libere o acesso para este site '
          '(Ajustes do Safari → Câmera) e tente de novo.';
    }
    if (c.contains('notfound') || c.contains('nocamera')) {
      return 'Nenhuma câmera encontrada neste aparelho.';
    }
    if (c.contains('notreadable') || c.contains('inuse')) {
      return 'A câmera está em uso por outro app ou aba. Feche-os e tente de novo.';
    }
    return 'Erro da câmera (${e.code}): ${e.description ?? ''}';
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _errorMsg = msg;
      _loading = false;
    });
  }

  Future<void> _startCamera(CameraDescription cam) async {
    // Sem áudio: o app só tira fotos (evita pedir o microfone).
    final ctrl = CameraController(cam, ResolutionPreset.medium,
        enableAudio: false);
    try {
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _controller = ctrl;
        _loading = false;
      });
    } on CameraException catch (e) {
      _fail(_friendly(e));
    } catch (e) {
      _fail('Erro ao inicializar a câmera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final xFile = await _controller!.takePicture();
      var path = xFile.path;
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        path = '${dir.path}/foto_$ts.jpg';
        await File(xFile.path).copy(path);
      }

      setState(() => _capturedPath = path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  void _retake() => setState(() => _capturedPath = null);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(ctrl.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Câmera')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_errorMsg!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    if (_capturedPath != null) {
      return Column(
        children: [
          Expanded(
            child: kIsWeb
                ? Image.network(_capturedPath!,
                    fit: BoxFit.cover, width: double.infinity)
                : Image.file(File(_capturedPath!),
                    fit: BoxFit.cover, width: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Nova foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _capturedPath),
                    icon: const Icon(Icons.check),
                    label: const Text('Usar foto'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Preview ao vivo
    final ctrl = _controller!;
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            // Na web o preview é um elemento HTML (platform view): não pode
            // ser escalado com FittedBox, então usamos a proporção nativa.
            child: kIsWeb
                ? AspectRatio(
                    aspectRatio: ctrl.value.aspectRatio,
                    child: CameraPreview(ctrl),
                  )
                : ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 1,
                          height: 1 / ctrl.value.aspectRatio,
                          child: CameraPreview(ctrl),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: GestureDetector(
            onTap: _takePicture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey[400]!, width: 4),
              ),
              child: const Icon(Icons.camera_alt, size: 36, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}
