// lib/pages/map_import_page.dart (VERSÃO ATUALIZADA)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geoforestcoletor/services/geojson_service.dart';
import 'package:geoforestcoletor/services/sampling_service.dart'; // <-- IMPORT DO NOVO SERVIÇO

class MapImportPage extends StatefulWidget {
  const MapImportPage({super.key});

  @override
  State<MapImportPage> createState() => _MapImportPageState();
}

class _MapImportPageState extends State<MapImportPage> {
  final _geoJsonService = GeoJsonService();
  final _samplingService = SamplingService(); // <-- Instancia o novo serviço

  List<Polygon> _polygons = [];
  List<LatLng> _samplePoints = []; // <-- Lista para guardar os pontos gerados
  bool _isLoading = false;

  Future<void> _handleImport() async {
    setState(() {
      _isLoading = true;
      _polygons = [];
      _samplePoints = []; // Limpa os pontos antigos
    });
    final importedPolygons = await _geoJsonService.importAndParseGeoJson();
    setState(() {
      _polygons = importedPolygons;
      _isLoading = false;
    });
    if (importedPolygons.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nenhum polígono importado.")));
    }
  }

  Future<void> _showDensityDialog() async {
    final densityController = TextEditingController();
    final hectares = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Densidade de Amostragem'),
        content: TextField(
          controller: densityController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Hectares por amostra',
            hintText: 'Ex: 2.5',
            suffixText: 'ha',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(densityController.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Gerar'),
          ),
        ],
      ),
    );

    if (hectares != null && _polygons.isNotEmpty) {
      setState(() => _isLoading = true);
      // Simula um pequeno atraso para o loading ser visível
      await Future.delayed(const Duration(milliseconds: 50));

      // Chama nosso novo serviço para gerar os pontos
      // Usamos apenas o primeiro polígono importado para este exemplo
      final points = _samplingService.generateSamplePoints(
        polygon: _polygons.first,
        hectaresPerSample: hectares,
      );
      
      setState(() {
        _samplePoints = points;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${points.length} amostras geradas!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar e Amostrar'),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _isLoading ? null : _handleImport, tooltip: 'Importar GeoJSON'),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(center: LatLng(-15.7, -47.8), zoom: 5),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
              
              // Camada para desenhar o polígono importado
              if (_polygons.isNotEmpty) PolygonLayer(polygons: _polygons),

              // Camada para desenhar os pontos de amostra gerados
              if (_samplePoints.isNotEmpty)
                MarkerLayer(
                  markers: _samplePoints.map((point) {
                    return Marker(
                      width: 40.0,
                      height: 40.0,
                      point: point,
                      child: const Icon(Icons.location_on, size: 30.0, color: Colors.red),
                    );
                  }).toList(),
                ),
            ],
          ),
          if (_isLoading) Container(color: Colors.black.withOpacity(0.3), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
      // Botão para gerar as amostras, só aparece se um polígono for importado
      floatingActionButton: _polygons.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _showDensityDialog,
              label: const Text('Gerar Amostras'),
              icon: const Icon(Icons.grid_on),
            )
          : null,
    );
  }
}