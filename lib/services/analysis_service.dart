// lib/services/analysis_service.dart (VERSÃO CORRIGIDA)

import 'dart:math';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';

class RendimentoDAP {
  final String classe; 
  final double volumePorHectare;
  final double porcentagemDoTotal;
  final int arvoresPorHectare;

  RendimentoDAP({
    required this.classe,
    required this.volumePorHectare,
    required this.porcentagemDoTotal,
    required this.arvoresPorHectare,
  });
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
    
    final List<Arvore> arvoresVivas = arvoresDoConjunto.where((a) => a.codigo == Codigo.normal).toList();

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
      // <<< CORREÇÃO: Usando o nome correto da variável (a minúsculo) >>>
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
    
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.codigo == Codigo.normal).toList();
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
  
  List<RendimentoDAP> analisarRendimentoPorDAP(List<Parcela> parcelasDoTalhao, List<Arvore> todasAsArvores) {
    if (parcelasDoTalhao.isEmpty || todasAsArvores.isEmpty) {
      return [];
    }
    
    final double areaTotalAmostradaM2 = parcelasDoTalhao.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    if (areaTotalAmostradaM2 == 0) return [];
    
    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.codigo == Codigo.normal).toList();
    final List<double> alturasValidas = arvoresVivas.map((a) => a.altura).whereType<double>().toList();
    final double mediaAltura = alturasValidas.isNotEmpty ? _calculateAverage(alturasValidas) : 0.0;

    for (var arv in arvoresVivas) {
      arv.volume = _estimateVolume(arv.cap, arv.altura ?? mediaAltura);
    }
    
    final Map<String, List<Arvore>> arvoresPorClasse = {
      '8-18 cm': [],
      '18-23 cm': [],
      '23-35 cm': [],
      '> 35 cm': [],
      'Outros': [],
    };

    for (var arv in arvoresVivas) {
      final double dap = arv.cap / pi;
      if (dap >= 8 && dap < 18) {
        arvoresPorClasse['8-18 cm']!.add(arv);
      } else if (dap >= 18 && dap < 23) {
        arvoresPorClasse['18-23 cm']!.add(arv);
      } else if (dap >= 23 && dap < 35) {
        arvoresPorClasse['23-35 cm']!.add(arv);
      } else if (dap >= 35) {
        arvoresPorClasse['> 35 cm']!.add(arv);
      } else {
        arvoresPorClasse['Outros']!.add(arv);
      }
    }

    final double volumeTotal = arvoresPorClasse.values
        .expand((arvores) => arvores)
        .map((arv) => arv.volume ?? 0)
        .fold(0.0, (a, b) => a + b);

    final List<RendimentoDAP> resultadoFinal = [];

    arvoresPorClasse.forEach((classe, arvores) {
      if (arvores.isNotEmpty) {
        final double volumeClasse = arvores.map((a) => a.volume ?? 0).reduce((a, b) => a + b);
        final double volumeHa = volumeClasse / areaTotalAmostradaHa;
        final double porcentagem = (volumeTotal > 0) ? (volumeClasse / volumeTotal) * 100 : 0;
        final int arvoresHa = (arvores.length / areaTotalAmostradaHa).round();
        
        resultadoFinal.add(RendimentoDAP(
          classe: classe,
          volumePorHectare: volumeHa,
          porcentagemDoTotal: porcentagem,
          arvoresPorHectare: arvoresHa,
        ));
      }
    });

    return resultadoFinal;
  }

  Map<String, int> gerarPlanoDeCubagem(
    Map<double, int> distribuicaoAmostrada,
    int totalArvoresAmostradas,
    int totalArvoresParaCubar,
    {int larguraClasse = 5}
  ) {
    if (totalArvoresAmostradas == 0 || totalArvoresParaCubar == 0) return {};

    final Map<String, int> plano = {};

    for (var entry in distribuicaoAmostrada.entries) {
      final pontoMedio = entry.key;
      final contagemNaClasse = entry.value;

      final double proporcao = contagemNaClasse / totalArvoresAmostradas;
      
      final int arvoresParaCubarNestaClasse = (proporcao * totalArvoresParaCubar).round();
      
      final inicioClasse = pontoMedio - (larguraClasse / 2);
      final fimClasse = pontoMedio + (larguraClasse / 2) - 0.1;
      final String rotuloClasse = "${inicioClasse.toStringAsFixed(1)} - ${fimClasse.toStringAsFixed(1)} cm";

      if (arvoresParaCubarNestaClasse > 0) {
        plano[rotuloClasse] = arvoresParaCubarNestaClasse;
      }
    }
    
    int somaAtual = plano.values.fold(0, (a, b) => a + b);
    int diferenca = totalArvoresParaCubar - somaAtual;
    
    if (diferenca != 0 && plano.isNotEmpty) {
      String classeParaAjustar = plano.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      plano.update(classeParaAjustar, (value) => value + diferenca, ifAbsent: () => diferenca);
      
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
      if (arvore.codigo == Codigo.normal && arvore.cap > 0) {
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