// lib/configuracoes_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mapeamento completo, igual ao do database_helper
const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978,
  'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980,
  'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982, // Seu projeto
  'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984,
  'SIRGAS 2000 / UTM Zona 25S': 31985,
};

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  String? _zonaSelecionada;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // <<< AJUSTE: O padrão agora é a sua zona 22S >>>
      _zonaSelecionada =
          prefs.getString('zona_utm_selecionada') ??
          'SIRGAS 2000 / UTM Zona 22S';
    });
  }

  Future<void> _salvarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zona_utm_selecionada', _zonaSelecionada!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações de Coordenadas')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zona UTM de Exportação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Escolha o sistema de coordenadas para o qual os dados serão convertidos no arquivo CSV.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (_zonaSelecionada == null)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _zonaSelecionada,
                isExpanded: true, // Garante que o texto não seja cortado
                items: zonasUtmSirgas2000.keys.map((String zona) {
                  return DropdownMenuItem<String>(
                    value: zona,
                    child: Text(zona, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (String? novoValor) {
                  setState(() {
                    _zonaSelecionada = novoValor;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Sistema de Coordenadas',
                  border: OutlineInputBorder(),
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Salvar Configurações'),
                onPressed: _salvarConfiguracoes,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
