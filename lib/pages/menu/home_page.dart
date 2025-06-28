// lib/pages/menu/home_page.dart (VERSÃO FINAL SEM SINCRONIZAÇÃO)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/pages/amostra/lista_projetos_page.dart';
import 'package:geoforestcoletor/pages/menu/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/menu/sobre_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geoforestcoletor/widgets/menu_card.dart';
import 'package:provider/provider.dart';
import 'package:geoforestcoletor/pages/analises/analise_selecao_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // REMOVIDO: final SyncService _syncService = SyncService();
  // REMOVIDO: bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // REMOVIDO: Lógica de sincronização automática
    // Future.delayed(const Duration(seconds: 1), () {
    //   print("HomePage: Tentando sincronização automática...");
    //   _syncService.syncData();
    // });
  }

  // REMOVIDO: Método _handleSync()
  // Future<void> _handleSync() async {
  //   if (_isSyncing) return;
  //   setState(() => _isSyncing = true);
  //   final scaffoldMessenger = ScaffoldMessenger.of(context);
  //   scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Iniciando sincronização...')));

  //   try {
  //     final count = await _syncService.syncData();
  //     if (!mounted) return;
  //     if (count > 0) {
  //       scaffoldMessenger.showSnackBar(SnackBar(content: Text('$count registros foram sincronizados!'), backgroundColor: Colors.green));
  //     } else {
  //       scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Nenhum dado novo para sincronizar.')));
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro na sincronização: $e'), backgroundColor: Colors.red));
  //   } finally {
  //     if (mounted) setState(() => _isSyncing = false);
  //   }
  // }

   void _abrirAnalistaDeDados(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnaliseSelecaoPage()),
    );
  }

  void _mostrarDialogoExportacao(BuildContext context) {
    final dbHelper = DatabaseHelper.instance; 
    final exportService = ExportService();
    final mapProvider = context.read<MapProvider>();
    showModalBottomSheet(context: context, builder: (ctx) => Container(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10), child: Wrap(spacing: 10, runSpacing: 10, children: [Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 10), child: Text('Escolha o que deseja exportar', style: Theme.of(context).textTheme.titleLarge)), ListTile(leading: const Icon(Icons.table_rows_outlined, color: Colors.green), title: const Text('Coletas de Parcela (CSV)'), subtitle: const Text('Exporta os dados de parcelas e árvores.'), onTap: () {Navigator.of(ctx).pop(); dbHelper.exportarDados(context);}), ListTile(leading: const Icon(Icons.table_chart_outlined, color: Colors.brown), title: const Text('Cubagens Rigorosas (CSV)'), subtitle: const Text('Exporta os dados de cubagens e seções.'), onTap: () {Navigator.of(ctx).pop(); dbHelper.exportarCubagens(context);}), ListTile(leading: const Icon(Icons.map_outlined, color: Colors.purple), title: const Text('Projeto do Mapa (GeoJSON)'), subtitle: const Text('Exporta os polígonos e pontos do mapa atual.'), onTap: () {Navigator.of(ctx).pop(); if (mapProvider.polygons.isEmpty && mapProvider.samplePoints.isEmpty) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há projeto carregado no mapa para exportar.'))); return;} exportService.exportProjectAsGeoJson(context: context, areaPolygons: mapProvider.polygons, samplePoints: mapProvider.samplePoints, farmName: mapProvider.farmName, blockName: mapProvider.blockName);})])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2, crossAxisSpacing: 12.0, mainAxisSpacing: 12.0, childAspectRatio: 1.0,
          children: [
            MenuCard(icon: Icons.explore_outlined, label: 'Navegação', onTap: () => Navigator.pushNamed(context, '/map_import')),
            MenuCard(icon: Icons.insights_outlined, label: 'GeoForest Analista',  onTap: () => _abrirAnalistaDeDados(context)),
            MenuCard(icon: Icons.checklist_rtl_outlined, label: 'Painel de Coletas', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaColetasPage(title: 'Painel de Coletas')))),
            // REMOVIDO: MenuCard de Sincronizar Dados
            // MenuCard(
            //   icon: _isSyncing ? Icons.hourglass_top_outlined : Icons.sync_outlined,
            //   label: 'Sincronizar Dados',
            //   onTap: _isSyncing ? () {} : () => _handleSync(),
            // ),
            MenuCard(icon: Icons.upload_file_outlined, label: 'Exportar Dados', onTap: () => _mostrarDialogoExportacao(context)),
            MenuCard(icon: Icons.settings_outlined, label: 'Configurações', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfiguracoesPage()))),
            MenuCard(icon: Icons.info_outline, label: 'Sobre', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SobrePage()))),
          ],
        ),
      ),
    );
  }
}
