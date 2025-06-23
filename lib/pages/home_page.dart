// lib/pages/home_page.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/helpers/database_helper.dart';
import 'package:geoforestcoletor/pages/coleta_dados_page.dart';
import 'package:geoforestcoletor/pages/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/lista_coletas_page.dart';
import 'package:geoforestcoletor/pages/sobre_page.dart';
import 'package:geoforestcoletor/widgets/menu_card.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});
  final String title;

  // Função para abrir o Google Maps
  void _abrirNavegacao(BuildContext context) async {
    final uri = Uri.parse('https://www.google.com/maps');
    
    if (!context.mounted) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o mapa.')),
      );
    }
  }
  
  // <<< NOVO MÉTODO ADICIONADO AQUI
  // Exibe um diálogo para o usuário escolher o que exportar.
  void _mostrarDialogoExportacao(BuildContext context) {
    final dbHelper = DatabaseHelper(); // Instancia o helper do banco de dados

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar Dados'),
        content: const Text('Qual tipo de dado você deseja exportar em CSV?'),
        actions: [
          TextButton(
            child: const Text('Coletas de Parcela'),
            onPressed: () {
              Navigator.of(ctx).pop(); // Fecha o diálogo
              dbHelper.exportarDados(context); // Chama a função de exportar coletas
            },
          ),
          TextButton(
            child: const Text('Cubagens Rigorosas'),
            onPressed: () {
              Navigator.of(ctx).pop(); // Fecha o diálogo
              dbHelper.exportarCubagens(context); // Chama a função de exportar cubagens
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
            MenuCard(icon: Icons.explore_outlined, label: 'Navegação', onTap: () => _abrirNavegacao(context)),
            MenuCard(icon: Icons.add_location_alt_outlined, label: 'Nova Coleta', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ColetaDadosPage()))),
            MenuCard(icon: Icons.checklist_rtl_outlined, label: 'Painel de Coletas', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaColetasPage(title: 'Painel de Coletas')))),
            
            // <<< CARD ATUALIZADO AQUI
            // O card "Exportar Coletas" foi substituído por este.
            MenuCard(
              icon: Icons.upload_file_outlined, // Ícone unificado para exportação
              label: 'Exportar Dados',
              onTap: () => _mostrarDialogoExportacao(context), // Chama o novo diálogo
            ),
                        
            // Card para importar mapa (se existir a rota)
            // MenuCard(icon: Icons.map_outlined, label: 'Importar Mapa', onTap: () => Navigator.pushNamed(context, '/map_import')),
            
            MenuCard(icon: Icons.settings_outlined, label: 'Configurações', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfiguracoesPage()))),
            MenuCard(icon: Icons.info_outline, label: 'Sobre', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SobrePage()))),
          ],
        ),
      ),
    );
  }
}