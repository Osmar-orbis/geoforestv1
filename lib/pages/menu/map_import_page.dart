// lib/pages/menu/map_import_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/pages/amostra/coleta_dados_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';


class MapImportPage extends StatefulWidget {
  const MapImportPage({super.key});

  @override
  State<MapImportPage> createState() => _MapImportPageState();
}

class _MapImportPageState extends State<MapImportPage> {
  final _mapController = MapController();
  final _exportService = ExportService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<MapProvider>();
      await provider.loadLastProject();
      if (mounted && provider.polygons.isNotEmpty) {
        _mapController.fitBounds(
          LatLngBounds.fromPoints(
            provider.polygons.expand((p) => p.points).toList(),
          ),
          options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
        );
      }
    });
  }

  Color _getMarkerColor(SampleStatus status) {
    switch (status) {
      case SampleStatus.open: return Colors.orange.shade300;
      case SampleStatus.completed: return Colors.green;
      case SampleStatus.exported: return Colors.blue;
      case SampleStatus.untouched:
      return Colors.white;
    }
  }

  Color _getMarkerTextColor(SampleStatus status) {
    switch (status) {
      case SampleStatus.open:
      case SampleStatus.untouched: return Colors.black;
      case SampleStatus.completed:
      case SampleStatus.exported:
      return Colors.white;
    }
  }

  Future<void> _handleImport() async {
    final provider = context.read<MapProvider>();
    final bool success = await provider.importAndClear(); 
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo lido com sucesso!')));
      
      if (provider.samplePoints.isNotEmpty && provider.polygons.isEmpty) {
        final projectData = await _showDataInputDialog(isImport: true);
        if (projectData != null) {
          await provider.saveImportedProject(
            farmName: projectData['farmName'],
            blockName: projectData['blockName'],
            idFazenda: projectData['farmId'],
          );
        }
      }

      if (provider.polygons.isNotEmpty) {
        _mapController.fitBounds(LatLngBounds.fromPoints(provider.polygons.expand((p) => p.points).toList()), options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)));
      }

    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nenhum polígono ou ponto válido foi encontrado no arquivo.")));
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
      idFazenda: sampleData['farmId'],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count amostras geradas!')));
    }
  }

  Future<Map<String, dynamic>?> _showDataInputDialog({bool isImport = false}) {
    final formKey = GlobalKey<FormState>();
    final densityController = TextEditingController();
    final farmController = TextEditingController();
    final blockController = TextEditingController();
    final farmIdController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isImport ? 'Dados do Projeto Importado' : 'Dados da Amostragem'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: farmController, autofocus: true, decoration: const InputDecoration(labelText: 'Nome da Fazenda'), validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null),
                const SizedBox(height: 8),
                TextFormField(controller: farmIdController, decoration: const InputDecoration(labelText: 'Código da Fazenda (Opcional)')),
                const SizedBox(height: 8),
                TextFormField(controller: blockController, decoration: const InputDecoration(labelText: 'Nome do Talhão'), validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null),
                if (!isImport)
                  TextFormField(controller: densityController, decoration: const InputDecoration(labelText: 'Hectares por amostra', suffixText: 'ha'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (value) { if (value == null || value.isEmpty) return 'Campo obrigatório'; if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Número inválido'; return null; }),
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
                  'farmId': farmIdController.text.trim(),
                  'blockName': blockController.text.trim(),
                  'hectares': isImport ? 0.0 : double.parse(densityController.text.replaceAll(',', '.')),
                });
              }
            },
            child: Text(isImport ? 'Salvar Projeto' : 'Gerar'),
          ),
        ],
      ),
    );
  }

  void _confirmClearMap() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Limpar Mapa?'), content: const Text('Isso removerá todos os polígonos e pontos de amostra importados. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(child: const Text('Limpar', style: TextStyle(color: Colors.red)), onPressed: () { context.read<MapProvider>().clearMapData(); Navigator.of(ctx).pop(); }),
        ],
      ),
    );
  }

  Future<void> _handleLocationButtonPressed() async {
    final provider = context.read<MapProvider>();

    if (provider.isFollowingUser) {
      provider.toggleFollowingUser();
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serviço de GPS desabilitado.')));
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada.')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada permanentemente.')));
      return;
    } 
    try {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando sua localização...')));
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
      provider.updateUserPosition(position);
      provider.toggleFollowingUser();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível obter a localização: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final currentUserPosition = mapProvider.currentUserPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Amostragem'),
        actions: [
          if (mapProvider.polygons.isNotEmpty || mapProvider.samplePoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _exportService.exportProjectAsGeoJson(
                context: context,
                areaPolygons: mapProvider.polygons,
                samplePoints: mapProvider.samplePoints,
                farmName: mapProvider.farmName,
                blockName: mapProvider.blockName,
              ),
              tooltip: 'Exportar Projeto (GeoJSON)',
            ),
          IconButton(icon: const Icon(Icons.file_upload_outlined), onPressed: mapProvider.isLoading ? null : _handleImport, tooltip: 'Importar Novo GeoJSON'),
          if (mapProvider.polygons.isNotEmpty && !mapProvider.isLoading) IconButton(icon: const Icon(Icons.delete_sweep_outlined), onPressed: _confirmClearMap, tooltip: 'Limpar Mapa'),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(-15.7, -47.8),
              zoom: 4,
              onPositionChanged: (position, hasGesture) {
                if (mapProvider.isFollowingUser && hasGesture) {
                  context.read<MapProvider>().toggleFollowingUser();
                }
              },
            ),
            children: [
              TileLayer(urlTemplate: mapProvider.currentTileUrl, userAgentPackageName: 'com.example.geoforestcoletor'),
              if (mapProvider.polygons.isNotEmpty) PolygonLayer(polygons: mapProvider.polygons),
              MarkerLayer(
                markers: mapProvider.samplePoints.map((samplePoint) {
                  final color = _getMarkerColor(samplePoint.status);
                  final textColor = _getMarkerTextColor(samplePoint.status);
                  return Marker(
                    width: 40.0, height: 40.0,
                    point: samplePoint.position,
                    child: GestureDetector(
                      onTap: () async {
                        final dbId = samplePoint.data['dbId'] as int?;
                        if (dbId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: ID da parcela não encontrado.')));
                          return;
                        }
                        final parcela = await DatabaseHelper().getParcelaById(dbId);
                        if (parcela == null || !mounted) return;
                        final foiAtualizado = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (context) => ColetaDadosPage(parcelaParaEditar: parcela)),
                        );
                        if (foiAtualizado == true && mounted) {
                          await context.read<MapProvider>().loadSamplesFromDb(
                                farmName: mapProvider.farmName,
                                blockName: mapProvider.blockName,
                              );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(2, 2))]),
                        child: Center(child: Text(samplePoint.id.toString(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (currentUserPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0, height: 80.0,
                      point: LatLng(currentUserPosition.latitude, currentUserPosition.longitude),
                      child: Transform.rotate(
                        angle: (currentUserPosition.heading * (pi / 180)),
                        child: const Icon(Icons.navigation, color: Colors.blue, size: 40, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (mapProvider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Processando...", style: TextStyle(color: Colors.white, fontSize: 16))])),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _handleLocationButtonPressed,
            tooltip: 'Minha Localização',
            heroTag: 'centerLocationFab',
            backgroundColor: mapProvider.isFollowingUser ? Colors.blue : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            child: Icon(mapProvider.isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () { context.read<MapProvider>().switchMapLayer(); },
            tooltip: 'Mudar Camada do Mapa', heroTag: 'switchLayerFab',
            mini: true,
            child: Icon(mapProvider.currentLayer == MapLayerType.ruas ? Icons.satellite_outlined : (mapProvider.currentLayer == MapLayerType.satelite ? Icons.terrain : Icons.map_outlined)),
          ),
          const SizedBox(height: 16),
          if (mapProvider.polygons.isNotEmpty)
            FloatingActionButton.extended(
              onPressed: _handleGenerateSamples, label: const Text('Gerar Amostras'), icon: const Icon(Icons.grid_on_sharp), heroTag: 'generateSamplesFab',
            ),
        ],
      ),
    );
  }
}