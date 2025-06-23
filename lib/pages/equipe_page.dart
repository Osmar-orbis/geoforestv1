// lib/pages/equipe_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EquipePage extends StatefulWidget {
  const EquipePage({super.key});

  @override
  State<EquipePage> createState() => _EquipePageState();
}

class _EquipePageState extends State<EquipePage> {
  final _formKey = GlobalKey<FormState>();
  final _liderController = TextEditingController();
  final _ajudantesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarNomesSalvos();
  }

  Future<void> _carregarNomesSalvos() async {
    final prefs = await SharedPreferences.getInstance();
    _liderController.text = prefs.getString('nome_lider') ?? '';
    _ajudantesController.text = prefs.getString('nomes_ajudantes') ?? '';
  }

  void _continuar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nome_lider', _liderController.text);
      await prefs.setString('nomes_ajudantes', _ajudantesController.text);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identificação da Equipe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Antes de começar, por favor, identifique a equipe de hoje.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _liderController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Líder da Equipe',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.trim().isEmpty
                    ? 'O nome do líder é obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ajudantesController,
                decoration: const InputDecoration(
                  labelText: 'Nomes dos Ajudantes',
                  hintText: 'Ex: João, Maria, Pedro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _continuar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Continuar para o Menu'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
