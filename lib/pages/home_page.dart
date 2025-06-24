// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/helpers/database_helper.dart';
import 'package:geoforestcoletor/pages/coleta_dados_page.dart';
import 'package:geoforestcoletor/pages/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/lista_coletas_page.dart';
import 'package:geoforestcoletor/pages/sobre_page.dart';
import 'package:geoforestcoletor/widgets/menu_card.dart';
// Removi o import do url_launcher, pois a função que o usava foi substituída.
// import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});
  final String title;

  // A função _abrirNavegacao não é mais necessária, mas pode ser mantida se quiser.
  // void _abrirNavegacao(BuildContext context) async { ... }
  
  void _mostrarDialogoExportacao(BuildContext context) {
    final dbHelper = DatabaseHelper();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar Dados'),
        content: const Text('Qual tipo de dado você deseja exportar em CSV?'),
        actions: [
          TextButton(
            child: const Text('Coletas de Parcela'),
            onPressed: () {
              Navigator.of(ctx).pop();
              dbHelper.exportarDados(context);
            },
          ),
          TextButton(
            child: const Text('Cubagens Rigorosas'),
            onPressed: () {
              Navigator.of(ctx).pop();
              dbHelper.exportarCubagens(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 1.0,
          children: [
            
            // =============================================================
            // =================== ALTERAÇÃO FEITA AQUI ====================
            // =============================================================
            // O antigo card "Navegação" foi substituído por este:
            MenuCard(
              icon: Icons.explore_outlined, // Um ícone mais adequado
              label: 'Navegação', 
              onTap: () => Navigator.pushNamed(context, '/map_import'), // Navega para a nova rota
            ),
            // =============================================================

            // O resto dos seus cards permanece exatamente igual
            MenuCard(icon: Icons.add_location_alt_outlined, label: 'Nova Coleta', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ColetaDadosPage()))),
            MenuCard(icon: Icons.checklist_rtl_outlined, label: 'Painel de Coletas', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaColetasPage(title: 'Painel de Coletas')))),
            MenuCard(
              icon: Icons.upload_file_outlined,
              label: 'Exportar Dados',
              onTap: () => _mostrarDialogoExportacao(context),
            ),
            MenuCard(icon: Icons.settings_outlined, label: 'Configurações', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfiguracoesPage()))),
            MenuCard(icon: Icons.info_outline, label: 'Sobre', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SobrePage()))),
          ],
        ),
      ),
    );
  }
}