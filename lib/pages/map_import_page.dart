// lib/pages/map_import_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/pages/coleta_dados_page.dart';
import 'package:flutter/services.dart';

class MapImportPage extends StatefulWidget {
  const MapImportPage({super.key});

  @override
  State<MapImportPage> createState() => _MapImportPageState();
}

class _MapImportPageState extends State<MapImportPage> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapProvider>();
      if (provider.polygons.isNotEmpty) {
        _mapController.fitBounds(
          LatLngBounds.fromPoints(
            provider.polygons.expand((p) => p.points).toList(),
          ),
          options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
        );
      }
    });
  }
  
  Future<void> _handleImport() async {
    final provider = context.read<MapProvider>();
    final count = await provider.importAndClear();
    
    if (!mounted) return;

    if (count > 0) {
      _mapController.fitBounds(
        LatLngBounds.fromPoints(provider.polygons.expand((p) => p.points).toList()),
        options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count polígono(s) importado(s).')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum polígono válido foi encontrado no arquivo.")),
      );
    }
  }

  Future<void> _handleGenerateSamples() async {
    final sampleData = await _showDataInputDialog();
    if (sampleData == null) return;
    
    final provider = context.read<MapProvider>();
    final count = await provider.generateSamples(
      hectaresPerSample: sampleData['hectares'],
      farmName: sampleData['farmName'],
      blockName: sampleData['blockName'],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count amostras geradas!')),
      );
    }
  }

  Future<Map<String, dynamic>?> _showDataInputDialog() {
    final formKey = GlobalKey<FormState>();
    final densityController = TextEditingController();
    final farmController = TextEditingController();
    final blockController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dados da Amostragem'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: farmController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome da Fazenda'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
                ),
                TextFormField(
                  controller: blockController,
                  decoration: const InputDecoration(labelText: 'Nome do Talhão'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
                ),
                TextFormField(
                  controller: densityController,
                  decoration: const InputDecoration(labelText: 'Hectares por amostra', suffixText: 'ha'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Campo obrigatório';
                    if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Número inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'farmName': farmController.text.trim(),
                  'blockName': blockController.text.trim(),
                  'hectares': double.parse(densityController.text.replaceAll(',', '.')),
                });
              }
            },
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
  }
  
  void _confirmClearMap() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar Mapa?'),
        content: const Text('Isso removerá todos os polígonos e pontos de amostra importados. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
            onPressed: () {
              context.read<MapProvider>().clearMapData();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Amostragem'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: mapProvider.isLoading ? null : _handleImport,
            tooltip: 'Importar Novo GeoJSON',
          ),
          if (mapProvider.polygons.isNotEmpty && !mapProvider.isLoading)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClearMap,
              tooltip: 'Limpar Mapa',
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: LatLng(-15.7, -47.8), zoom: 4),
            children: [
              TileLayer(
                urlTemplate: mapProvider.currentTileUrl,
                userAgentPackageName: 'com.example.geoforestcoletor',
              ),
              if (mapProvider.polygons.isNotEmpty) PolygonLayer(polygons: mapProvider.polygons),
              MarkerLayer(
                markers: mapProvider.samplePoints.map((samplePoint) {
                  return Marker(
                    width: 40.0,
                    height: 40.0,
                    point: samplePoint.position,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ColetaDadosPage(
                              nomeFazendaInicial: mapProvider.farmName,
                              nomeTalhaoInicial: mapProvider.blockName,
                              idParcelaInicial: samplePoint.id,
                            ),
                          ),
                        );
                      },
                      // <<< MARCADOR COM NÚMERO MAIS VISÍVEL >>>
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            samplePoint.id.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (mapProvider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Processando...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // <<< BOTÃO PARA TROCAR A CAMADA DO MAPA >>>
          FloatingActionButton(
            onPressed: () {
              context.read<MapProvider>().switchMapLayer();
            },
            tooltip: 'Mudar Camada do Mapa',
            heroTag: 'switchLayerFab',
            mini: true,
            child: Icon(
              mapProvider.currentLayer == MapLayerType.ruas
                ? Icons.satellite_outlined
                : Icons.map_outlined,
            ),
          ),
          const SizedBox(height: 16),
          if (mapProvider.polygons.isNotEmpty && !mapProvider.isLoading)
            FloatingActionButton.extended(
                onPressed: _handleGenerateSamples,
                label: const Text('Gerar Amostras'),
                icon: const Icon(Icons.grid_on_sharp),
                heroTag: 'generateSamplesFab',
            ),
        ],
      ),
    );
  }
}