// lib/pages/menu/home_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/pages/amostra/coleta_dados_page.dart';
import 'package:geoforestcoletor/pages/menu/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/amostra/lista_coletas_page.dart';
import 'package:geoforestcoletor/pages/menu/sobre_page.dart';
import 'package:geoforestcoletor/widgets/menu_card.dart';
import 'package:geoforestcoletor/models/parcela_model.dart'; // <<< 1. IMPORT NECESSÁRIO

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});
  final String title;

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
            MenuCard(
              icon: Icons.explore_outlined,
              label: 'Navegação', 
              onTap: () => Navigator.pushNamed(context, '/map_import'),
            ),
            
            // =========================================================================
            // ======================== CORREÇÃO APLICADA AQUI =========================
            // =========================================================================
            MenuCard(
              icon: Icons.add_location_alt_outlined,
              label: 'Nova Coleta',
              onTap: () {
                // 1. Cria um objeto Parcela "vazio" com os valores mínimos necessários.
                final novaParcelaAvulsa = Parcela(
                  nomeFazenda: '', 
                  nomeTalhao: '', 
                  idParcela: '', 
                  areaMetrosQuadrados: 0, 
                  status: StatusParcela.pendente // O status 'pendente' indica uma nova entrada
                );

                // 2. Navega para a ColetaDadosPage, passando a parcela "vazia" para ser preenchida.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Remove o 'const'
                    builder: (context) => ColetaDadosPage(parcelaParaEditar: novaParcelaAvulsa),
                  ),
                );
              },
            ),
            // =========================================================================
            
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