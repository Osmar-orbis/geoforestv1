// lib/pages/screens/map_import_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/pages/coleta_dados_page.dart';
import 'package:geoforestcoletor/models/sample_point.dart'; // <<< 1. IMPORT NECESSÁRIO >>>

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
  
  // =========================================================================
  // ====================== NOVAS FUNÇÕES HELPER PARA COR ====================
  // =========================================================================
  /// Retorna a cor de fundo do marcador com base no status da parcela.
  Color _getMarkerColor(SampleStatus status) {
    switch (status) {
      case SampleStatus.open:
        return Colors.orange.shade300; // Laranja claro
      case SampleStatus.completed:
        return Colors.green; // Verde
      case SampleStatus.exported:
        return Colors.blue; // Azul
      case SampleStatus.untouched:
              return Colors.white; // Branco
    }
  }

  /// Retorna a cor do texto do marcador para garantir um bom contraste.
  Color _getMarkerTextColor(SampleStatus status) {
    switch (status) {
      case SampleStatus.open:
      case SampleStatus.untouched:
        return Colors.black; // Texto preto para fundos claros
      case SampleStatus.completed:
      case SampleStatus.exported:
       return Colors.white; // Texto branco para fundos escuros
    }
  }
  // =========================================================================


  Future<void> _handleImport() async {
    final provider = context.read<MapProvider>();
    // provider.importAndClear() agora limpa os dados antigos, garantindo a persistência correta.
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
    // Usamos 'watch' para que a tela reconstrua quando os dados no provider mudarem (ex: cores)
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
                // O loop agora renderiza os marcadores com as cores dinâmicas
                markers: mapProvider.samplePoints.map((samplePoint) {
                  // Pega as cores certas usando as novas funções helper
                  final color = _getMarkerColor(samplePoint.status);
                  final textColor = _getMarkerTextColor(samplePoint.status);

                  return Marker(
                    width: 40.0,
                    height: 40.0,
                    point: samplePoint.position,
                    child: GestureDetector(
                      onTap: () {
                        // <<< LÓGICA DE ATUALIZAÇÃO DE STATUS AO CLICAR >>>
                        // Apenas muda o status para 'aberto' se ele ainda não foi tocado.
                        if (samplePoint.status == SampleStatus.untouched) {
                          context.read<MapProvider>().updateSampleStatus(samplePoint.id, SampleStatus.open);
                        }

                        // A navegação para a página de coleta permanece a mesma.
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
                      // O widget Container agora usa as cores dinâmicas.
                      child: Container(
                        decoration: BoxDecoration(
                          color: color, // <<< USA A COR DINÂMICA
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
                            style: TextStyle(
                              color: textColor, // <<< USA A COR DE TEXTO DINÂMICA
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
      // Seu FloatingActionButton original foi mantido intacto.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              context.read<MapProvider>().switchMapLayer();
            },
            tooltip: 'Mudar Camada do Mapa',
            heroTag: 'switchLayerFab',
            mini: true,
            child: Icon(
              // Lógica de ícone para troca de camada mantida.
              mapProvider.currentLayer == MapLayerType.ruas
                ? Icons.satellite_outlined
                : (mapProvider.currentLayer == MapLayerType.satelite ? Icons.terrain : Icons.map_outlined),
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