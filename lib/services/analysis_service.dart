// lib/services/analysis_service.dart

import 'dart:math';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';

enum FinalidadeMadeira { celulose, energia, serraria, laminacao, postes }

extension FinalidadeExt on FinalidadeMadeira {
  String get descricao {
    switch (this) {
      case FinalidadeMadeira.celulose: return "Celulose";
      case FinalidadeMadeira.energia: return "Energia";
      case FinalidadeMadeira.serraria: return "Serraria";
      case FinalidadeMadeira.laminacao: return "Laminação";
      case FinalidadeMadeira.postes: return "Postes";
    }
  }
}

class TalhaoAnalysisResult {
  final double areaTotalAmostradaHa;
  final int totalArvoresAmostradas;
  final int totalParcelasAmostradas;
  final double mediaCap;
  final double mediaAltura;
  final double areaBasalPorHectare;
  final double volumePorHectare;
  final int arvoresPorHectare;
  final Map<double, int> distribuicaoDiametrica;
  final List<String> warnings;
  final List<String> insights;
  final List<String> recommendations;

  TalhaoAnalysisResult({
    this.areaTotalAmostradaHa = 0,
    this.totalArvoresAmostradas = 0,
    this.totalParcelasAmostradas = 0,
    this.mediaCap = 0,
    this.mediaAltura = 0,
    this.areaBasalPorHectare = 0,
    this.volumePorHectare = 0,
    this.arvoresPorHectare = 0,
    this.distribuicaoDiametrica = const {},
    this.warnings = const [],
    this.insights = const [],
    this.recommendations = const [],
  });
}

class RendimentoTalhaoResult {
  final Map<FinalidadeMadeira, double> volumePorHectare;
  final Map<FinalidadeMadeira, int> arvoresPorHectare;

  RendimentoTalhaoResult({
    required this.volumePorHectare,
    required this.arvoresPorHectare,
  });
}

class AnalysisService {
  static const double FATOR_DE_FORMA = 0.45;

  TalhaoAnalysisResult getTalhaoInsights(List<Parcela> parcelasDoTalhao, List<Arvore> todasAsArvores) {
    if (parcelasDoTalhao.isEmpty || todasAsArvores.isEmpty) {
      return TalhaoAnalysisResult();
    }
    
    final double areaTotalAmostradaM2 = parcelasDoTalhao.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    if (areaTotalAmostradaM2 == 0) return TalhaoAnalysisResult();
    
    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;

    return _analisarListaDeArvores(todasAsArvores, areaTotalAmostradaHa, parcelasDoTalhao.length);
  }

  TalhaoAnalysisResult _analisarListaDeArvores(List<Arvore> arvoresDoConjunto, double areaAmostradaHa, int numeroDeParcelas) {
    if (arvoresDoConjunto.isEmpty || areaAmostradaHa <= 0) {
      return TalhaoAnalysisResult();
    }
    
    final List<Arvore> arvoresVivas = arvoresDoConjunto.where((a) => a.status == StatusArvore.normal).toList();

    if (arvoresVivas.isEmpty) {
      return TalhaoAnalysisResult(warnings: ["Nenhuma árvore viva encontrada nas amostras para análise."]);
    }

    final double mediaCap = _calculateAverage(arvoresVivas.map((a) => a.cap).toList());
    final List<double> alturasValidas = arvoresVivas.map((a) => a.altura).whereType<double>().toList();
    final double mediaAltura = alturasValidas.isNotEmpty ? _calculateAverage(alturasValidas) : 0.0;
    
    final double areaBasalTotalAmostrada = arvoresVivas.map((a) => _areaBasalPorArvore(a.cap)).reduce((a, b) => a + b);
    final double areaBasalPorHectare = areaBasalTotalAmostrada / areaAmostradaHa;

    final double volumeTotalAmostrado = arvoresVivas.map((a) => _estimateVolume(a.cap, a.altura ?? mediaAltura)).reduce((a, b) => a + b);
    final double volumePorHectare = volumeTotalAmostrado / areaAmostradaHa;
    
    final int arvoresPorHectare = (arvoresVivas.length / areaAmostradaHa).round();

    List<String> warnings = [];
    List<String> insights = [];
    List<String> recommendations = [];
    
    final int arvoresMortas = arvoresDoConjunto.length - arvoresVivas.length;
    final double taxaMortalidade = (arvoresMortas / arvoresDoConjunto.length) * 100;
    if (taxaMortalidade > 15) {
      warnings.add("Mortalidade de ${taxaMortalidade.toStringAsFixed(1)}% detectada, valor considerado alto.");
    }

    if (areaBasalPorHectare > 38) {
      insights.add("A Área Basal (${areaBasalPorHectare.toStringAsFixed(1)} m²/ha) indica um povoamento muito denso.");
      recommendations.add("O talhão é um forte candidato para desbaste. Use a ferramenta de simulação para avaliar cenários.");
    } else if (areaBasalPorHectare < 20) {
      insights.add("A Área Basal (${areaBasalPorHectare.toStringAsFixed(1)} m²/ha) está baixa, indicando um povoamento aberto ou muito jovem.");
    }

    final Map<double, int> distribuicao = getDistribuicaoDiametrica(arvoresVivas);

    return TalhaoAnalysisResult(
      areaTotalAmostradaHa: areaAmostradaHa,
      totalArvoresAmostradas: arvoresDoConjunto.length,
      totalParcelasAmostradas: numeroDeParcelas,
      mediaCap: mediaCap,
      mediaAltura: mediaAltura,
      areaBasalPorHectare: areaBasalPorHectare,
      volumePorHectare: volumePorHectare,
      arvoresPorHectare: arvoresPorHectare,
      distribuicaoDiametrica: distribuicao, 
      warnings: warnings,
      insights: insights,
      recommendations: recommendations,
    );
  }

  TalhaoAnalysisResult simularDesbaste(List<Parcela> parcelasOriginais, List<Arvore> todasAsArvores, double porcentagemRemocao) {
    if (parcelasOriginais.isEmpty || porcentagemRemocao <= 0) {
      return getTalhaoInsights(parcelasOriginais, todasAsArvores);
    }
    
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.status == StatusArvore.normal).toList();
    if (arvoresVivas.isEmpty) {
      return getTalhaoInsights(parcelasOriginais, todasAsArvores);
    }

    arvoresVivas.sort((a, b) => a.cap.compareTo(b.cap));
    
    final int quantidadeRemover = (arvoresVivas.length * (porcentagemRemocao / 100)).floor();
    final List<Arvore> arvoresRemanescentes = arvoresVivas.sublist(quantidadeRemover);
    
    final double areaTotalAmostradaM2 = parcelasOriginais.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;

    return _analisarListaDeArvores(arvoresRemanescentes, areaTotalAmostradaHa, parcelasOriginais.length);
  }

  RendimentoTalhaoResult analisarRendimentoPorHectare(List<Parcela> parcelasDoTalhao, List<Arvore> todasAsArvores) {
    final double areaTotalAmostradaM2 = parcelasDoTalhao.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    
    final Map<FinalidadeMadeira, double> volumeTotalPorFinalidade = { for (var f in FinalidadeMadeira.values) f: 0.0 };
    final Map<FinalidadeMadeira, int> contagemPorFinalidade = { for (var f in FinalidadeMadeira.values) f: 0 };

    if (todasAsArvores.isEmpty || areaTotalAmostradaM2 == 0) {
      return RendimentoTalhaoResult(volumePorHectare: volumeTotalPorFinalidade, arvoresPorHectare: contagemPorFinalidade);
    }

    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.status == StatusArvore.normal).toList();
    final List<double> alturasValidas = arvoresVivas.map((a) => a.altura).whereType<double>().toList();
    final double mediaAltura = alturasValidas.isNotEmpty ? _calculateAverage(alturasValidas) : 0.0;

    for (var arv in arvoresVivas) {
      double volumeArvore = _estimateVolume(arv.cap, arv.altura ?? mediaAltura);
      
      if (arv.cap >= 20 && (arv.altura ?? mediaAltura) >= 12) {
        volumeTotalPorFinalidade[FinalidadeMadeira.serraria] = (volumeTotalPorFinalidade[FinalidadeMadeira.serraria] ?? 0) + volumeArvore;
        contagemPorFinalidade[FinalidadeMadeira.serraria] = (contagemPorFinalidade[FinalidadeMadeira.serraria] ?? 0) + 1;
      } else if (arv.cap >= 12 && arv.cap < 20) {
        volumeTotalPorFinalidade[FinalidadeMadeira.celulose] = (volumeTotalPorFinalidade[FinalidadeMadeira.celulose] ?? 0) + volumeArvore;
        contagemPorFinalidade[FinalidadeMadeira.celulose] = (contagemPorFinalidade[FinalidadeMadeira.celulose] ?? 0) + 1;
      } else if (arv.cap < 12) {
        volumeTotalPorFinalidade[FinalidadeMadeira.energia] = (volumeTotalPorFinalidade[FinalidadeMadeira.energia] ?? 0) + volumeArvore;
        contagemPorFinalidade[FinalidadeMadeira.energia] = (contagemPorFinalidade[FinalidadeMadeira.energia] ?? 0) + 1;
      }
    }
    
    final Map<FinalidadeMadeira, double> volumePorHectare = {};
    final Map<FinalidadeMadeira, int> arvoresPorHectare = {};
    for (var finalidade in volumeTotalPorFinalidade.keys) {
      volumePorHectare[finalidade] = (volumeTotalPorFinalidade[finalidade] ?? 0) / areaTotalAmostradaHa;
      arvoresPorHectare[finalidade] = ((contagemPorFinalidade[finalidade] ?? 0) / areaTotalAmostradaHa).round();
    }
    
    return RendimentoTalhaoResult(volumePorHectare: volumePorHectare, arvoresPorHectare: arvoresPorHectare);
  }

  // <<< NOVO MÉTODO ADICIONADO AQUI >>>
  /// Calcula quantas árvores devem ser cubadas por classe diamétrica.
  /// Retorna um mapa no formato { 'Classe_CAP': Contagem_Para_Cubar }
  Map<String, int> gerarPlanoDeCubagem(
    Map<double, int> distribuicaoAmostrada, // O resultado do getDistribuicaoDiametrica
    int totalArvoresAmostradas,
    int totalArvoresParaCubar, // O número 'X' que o usuário quer cubar
    {int larguraClasse = 5}
  ) {
    if (totalArvoresAmostradas == 0 || totalArvoresParaCubar == 0) return {};

    final Map<String, int> plano = {};

    // Calcula a proporção de árvores em cada classe na amostra
    for (var entry in distribuicaoAmostrada.entries) {
      final pontoMedio = entry.key;
      final contagemNaClasse = entry.value;

      // Calcula a porcentagem que essa classe representa do total amostrado
      final double proporcao = contagemNaClasse / totalArvoresAmostradas;
      
      // Aplica essa proporção ao número total de árvores a serem cubadas
      final int arvoresParaCubarNestaClasse = (proporcao * totalArvoresParaCubar).round();
      
      // Cria o rótulo da classe (ex: "20.0 - 24.9 cm")
      final inicioClasse = pontoMedio - (larguraClasse / 2);
      final fimClasse = pontoMedio + (larguraClasse / 2) - 0.1;
      final String rotuloClasse = "${inicioClasse.toStringAsFixed(1)} - ${fimClasse.toStringAsFixed(1)} cm";

      if (arvoresParaCubarNestaClasse > 0) {
        plano[rotuloClasse] = arvoresParaCubarNestaClasse;
      }
    }
    
    // Ajuste final para garantir que a soma seja exatamente `totalArvoresParaCubar`
    int somaAtual = plano.values.fold(0, (a, b) => a + b);
    int diferenca = totalArvoresParaCubar - somaAtual;
    
    if (diferenca != 0 && plano.isNotEmpty) {
      // Adiciona ou remove a diferença da classe com mais árvores para minimizar o impacto relativo
      String classeParaAjustar = plano.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      plano.update(classeParaAjustar, (value) => value + diferenca, ifAbsent: () => diferenca);
      
      // Garante que nenhuma classe fique com contagem negativa após o ajuste
      if (plano[classeParaAjustar]! <= 0) {
        plano.remove(classeParaAjustar);
      }
    }

    return plano;
  }
  
  Map<double, int> getDistribuicaoDiametrica(List<Arvore> arvores, {int larguraClasse = 5}) {
    if (arvores.isEmpty) return {};

    final Map<int, int> contagemPorClasse = {};
    
    for (final arvore in arvores) {
      if (arvore.status == StatusArvore.normal && arvore.cap > 0) {
        final int classeBase = (arvore.cap / larguraClasse).floor() * larguraClasse;
        contagemPorClasse.update(classeBase, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    
    final sortedKeys = contagemPorClasse.keys.toList()..sort();
    final Map<double, int> resultadoFinal = {};
    for (final key in sortedKeys) {
      final double pontoMedio = key.toDouble() + (larguraClasse / 2.0);
      resultadoFinal[pontoMedio] = contagemPorClasse[key]!;
    }

    return resultadoFinal;
  }

  double _areaBasalPorArvore(double cap) {
    if (cap <= 0) return 0;
    final double dap = cap / pi;
    return (pi * pow(dap, 2)) / 40000;
  }

  double _estimateVolume(double cap, double altura) {
    if (cap <= 0 || altura <= 0) return 0;
    final areaBasal = _areaBasalPorArvore(cap);
    return areaBasal * altura * FATOR_DE_FORMA;
  }

  double _calculateAverage(List<double> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a + b) / numbers.length;
  }
}