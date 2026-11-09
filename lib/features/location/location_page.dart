import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? _position;
  bool _loading = false;
  String? _errorMsg;

  Future<void> _getLocation() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMsg = 'Serviço de localização desativado.\nAcesse as configurações e ative o GPS.';
          _loading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMsg = 'Permissão de localização negada.';
            _loading = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMsg =
              'Permissão negada permanentemente.\nAbra as configurações do app para conceder acesso.';
          _loading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _position = pos;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Erro ao obter localização: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Localização GPS')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_on, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Obtenha suas coordenadas GPS atuais.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMsg != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_position != null)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        icon: Icons.north,
                        label: 'Latitude',
                        value: _position!.latitude.toStringAsFixed(6),
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.east,
                        label: 'Longitude',
                        value: _position!.longitude.toStringAsFixed(6),
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.height,
                        label: 'Altitude',
                        value:
                            '${_position!.altitude.toStringAsFixed(1)} m',
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.radar,
                        label: 'Precisão',
                        value:
                            '± ${_position!.accuracy.toStringAsFixed(1)} m',
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _loading ? null : _getLocation,
              icon: const Icon(Icons.gps_fixed),
              label: Text(_position == null
                  ? 'Obter localização'
                  : 'Atualizar localização'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
