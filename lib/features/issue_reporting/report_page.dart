import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/app_state.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/geo.dart';
import '../../models/issue_category.dart';
import '../../models/urban_issue.dart';
import '../camera/camera_page.dart';
import '../issue_details/issue_details_sheet.dart';

/// Fluxo de registro em 3 passos: foto → local → detalhes (seção 12.2).
class ReportPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const ReportPage({super.key, this.initialLat, this.initialLng});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  static const _titles = ['Foto', 'Local', 'Detalhes'];
  int _step = 0;

  String? _photo;

  LatLng? _point;
  double? _accuracy;
  bool _manual = false;
  bool _locating = false;
  String? _locError;
  final _map = MapController();

  IssueCategory? _category;
  Severity _severity = Severity.medium;
  final _desc = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _point = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final path = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const CameraPage()));
    if (path != null && mounted) setState(() => _photo = path);
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final pos = await LocationService.current();
      if (!mounted) return;
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _point = p;
        _accuracy = pos.accuracy;
        _manual = false;
      });
      try {
        _map.move(p, 18);
      } catch (_) {
        // Mapa ainda não montado: ele já abre centralizado em _point.
      }
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locError = e.message);
    } catch (_) {
      if (mounted) setState(() => _locError = 'Não foi possível obter o GPS.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _goTo(int step) {
    setState(() => _step = step);
    if (step == 1 && _point == null && !_locating) _fetchLocation();
  }

  Future<void> _save(AppState app) async {
    final cat = _category!;
    final pt = _point!;
    setState(() => _saving = true);
    final dups = app.issues.possibleDuplicates(pt.latitude, pt.longitude, cat);
    if (dups.isNotEmpty) {
      final d = dups.first;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.content_copy),
          title: const Text('Possível registro duplicado'),
          content: Text(
              'Já existe um registro de "${cat.label}" a ${formatDistance(distanceMeters(pt.latitude, pt.longitude, d.latitude, d.longitude))} deste ponto:\n\n"${d.description}"\n\nÉ o mesmo problema?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'new'),
                child: const Text('É outro problema')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'same'),
                child: const Text('Sim, confirmar o existente')),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == null) {
        setState(() => _saving = false);
        return;
      }
      if (choice == 'same') {
        await app.issues.confirmStillExists(d.id);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Confirmação adicionada ao registro existente.')));
        return;
      }
    }
    final UrbanIssue issue;
    try {
      final bytes = _photo == null ? null : await XFile(_photo!).readAsBytes();
      issue = await app.issues.add(
        category: cat,
        description: _desc.text,
        latitude: pt.latitude,
        longitude: pt.longitude,
        severity: _severity,
        photoBytes: bytes,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: const Text('Problema registrado! Obrigado por contribuir.'),
      action: SnackBarAction(
          label: 'VER', onPressed: () => showIssueDetails(nav.context, issue.id)),
    ));
  }

  bool get _canContinue => switch (_step) {
        0 => true,
        1 => _point != null,
        _ => _category != null,
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar problema'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Column(
            children: [
              LinearProgressIndicator(value: (_step + 1) / 3),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('Passo ${_step + 1} de 3 · ${_titles[_step]}',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: switch (_step) {
              0 => _photoStep(),
              1 => _locationStep(),
              _ => _detailsStep(),
            },
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                          onPressed: _saving ? null : () => _goTo(_step - 1),
                          child: const Text('Voltar')),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: !_canContinue || _saving
                          ? null
                          : () => _step < 2 ? _goTo(_step + 1) : _save(app),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_step < 2
                              ? (_step == 0 && _photo == null
                                  ? 'Continuar sem foto'
                                  : 'Continuar')
                              : 'Salvar registro'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoStep() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Fotografe o problema',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
            'Foque na calçada, rampa ou obstáculo. Evite pessoas identificáveis e placas de veículos.'),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Material(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _takePhoto,
              child: _photo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 56, color: cs.primary),
                        const SizedBox(height: 8),
                        const Text('Toque para abrir a câmera'),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        kIsWeb
                            ? Image.network(_photo!, fit: BoxFit.cover)
                            : Image.file(File(_photo!), fit: BoxFit.cover),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: FilledButton.tonalIcon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Trocar')),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationStep() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(_manual ? Icons.touch_app : Icons.gps_fixed, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _locating
                      ? 'Obtendo localização…'
                      : _locError != null
                          ? '$_locError Toque no mapa para marcar o ponto.'
                          : _point == null
                              ? 'Toque no mapa para marcar o ponto.'
                              : _manual
                                  ? 'Ponto ajustado manualmente.'
                                  : 'Precisão estimada: ~${_accuracy?.round() ?? '?'} m. Toque no mapa para ajustar.',
                ),
              ),
              IconButton(
                tooltip: 'Usar GPS novamente',
                onPressed: _locating ? null : _fetchLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _point ?? const LatLng(-23.5505, -46.6333),
              initialZoom: _point == null ? 14 : 18,
              onTap: (_, p) => setState(() {
                _point = p;
                _manual = true;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.com.cidadeinvisivel.cidade_invisivel',
              ),
              if (_point != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _point!,
                    width: 48,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on, size: 48, color: cs.error),
                  ),
                ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© colaboradores do OpenStreetMap')
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailsStep() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                      'A sugestão automática de categoria por IA ainda não está disponível. Escolha a categoria abaixo.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Categoria', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in IssueCategory.values)
              ChoiceChip(
                avatar: Icon(c.icon,
                    size: 18,
                    color: _category == c ? cs.onSecondaryContainer : c.color),
                label: Text(c.label),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        if (_category != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_category!.examples,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        const SizedBox(height: 20),
        Text('Gravidade', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<Severity>(
            segments: [
              for (final s in Severity.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {_severity},
            onSelectionChanged: (v) => setState(() => _severity = v.first),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _desc,
          maxLines: 3,
          maxLength: 280,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Descrição (opcional)',
            hintText: 'Ex.: buraco grande na calçada, em frente ao nº 120',
          ),
        ),
      ],
    );
  }
}
