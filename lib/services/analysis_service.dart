import 'dart:math';

import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
// import 'package:geoforestcoletor/services/prediction_service.dart'; // Descomente quando criar este serviço

// Enum para as finalidades comerciais da madeira
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

// Classe para encapsular os resultados da análise principal do talhão
class TalhaoAnalysisResult {
  // Métricas chave
  final double areaTotalAmostradaHa;
  final int totalArvoresAmostradas;
  final double mediaCap;
  final double mediaAltura;
  final double areaBasalPorHectare; // G/ha
  final double volumePorHectare; // m³/ha
  final int arvoresPorHectare;

  // Listas de texto para a UI
  final List<String> warnings;
  final List<String> insights;
  final List<String> recommendations;

  TalhaoAnalysisResult({
    this.areaTotalAmostradaHa = 0,
    this.totalArvoresAmostradas = 0,
    this.mediaCap = 0,
    this.mediaAltura = 0,
    this.areaBasalPorHectare = 0,
    this.volumePorHectare = 0,
    this.arvoresPorHectare = 0,
    this.warnings = const [],
    this.insights = const [],
    this.recommendations = const [],
  });
}

// Classe para encapsular os resultados da análise de rendimento
class RendimentoTalhaoResult {
  final Map<FinalidadeMadeira, double> volumePorHectare; // m³/ha por finalidade
  final Map<FinalidadeMadeira, int> arvoresPorHectare; // árvores/ha por finalidade

  RendimentoTalhaoResult({
    required this.volumePorHectare,
    required this.arvoresPorHectare,
  });
}

/// Serviço principal para análises florestais e simulações.
/// Opera em nível de talhão, agregando dados de múltiplas parcelas.
class AnalysisService {
  // final PredictionService _predictionService; // Futuro: Injetar o serviço de previsão
  // AnalysisService(this._predictionService);

  // Fator de forma médio para estimativa de volume. Ajuste conforme necessário.
  static const double FATOR_DE_FORMA = 0.45;

  /// Calcula as principais métricas e gera insights para um talhão inteiro.
  TalhaoAnalysisResult getTalhaoInsights(List<Parcela> parcelasDoTalhao) {
    if (parcelasDoTalhao.isEmpty) return TalhaoAnalysisResult();

    final List<Arvore> todasAsArvores = parcelasDoTalhao.expand((p) => p.arvores).toList();
    final double areaTotalAmostradaM2 = parcelasDoTalhao.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    
    if (todasAsArvores.isEmpty || areaTotalAmostradaM2 == 0) return TalhaoAnalysisResult();
    
    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.status == StatusArvore.normal).toList();

    if (arvoresVivas.isEmpty) return TalhaoAnalysisResult(
      warnings: ["Nenhuma árvore viva encontrada nas amostras para análise."]
    );

    // --- CÁLCULOS ESTATÍSTICOS ---
    final double mediaCap = _calculateAverage(arvoresVivas.map((a) => a.cap).toList());
    final double mediaAltura = _calculateAverage(arvoresVivas.map((a) => a.altura).whereType<double>().toList());
    
    final double areaBasalTotalAmostrada = arvoresVivas
        .map((a) => _areaBasalPorArvore(a.cap))
        .reduce((a, b) => a + b);
    final double areaBasalPorHectare = areaBasalTotalAmostrada / areaTotalAmostradaHa;

    final double volumeTotalAmostrado = arvoresVivas
        .map((a) => _estimateVolume(a.cap, a.altura ?? mediaAltura))
        .reduce((a, b) => a + b);
    final double volumePorHectare = volumeTotalAmostrado / areaTotalAmostradaHa;
    
    final int arvoresPorHectare = (arvoresVivas.length / areaTotalAmostradaHa).round();

    // --- GERAÇÃO DE INSIGHTS E RECOMENDAÇÕES ---
    List<String> warnings = [];
    List<String> insights = [];
    List<String> recommendations = [];
    
    // Análise de Mortalidade
    final int arvoresMortas = todasAsArvores.where((a) => a.status == StatusArvore.morta).length;
    final double taxaMortalidade = (arvoresMortas / todasAsArvores.length) * 100;
    if (taxaMortalidade > 15) {
      warnings.add("Mortalidade de ${taxaMortalidade.toStringAsFixed(1)}% detectada no talhão, valor considerado alto.");
    }

    // Análise de Competição baseada em Área Basal
    if (areaBasalPorHectare > 38) {
      insights.add("A Área Basal (${areaBasalPorHectare.toStringAsFixed(1)} m²/ha) indica um povoamento muito denso.");
      recommendations.add("O talhão é um forte candidato para desbaste. Use a ferramenta de simulação para avaliar cenários.");
    } else if (areaBasalPorHectare < 20) {
       insights.add("A Área Basal (${areaBasalPorHectare.toStringAsFixed(1)} m²/ha) está baixa, indicando um povoamento aberto ou muito jovem.");
    }

    return TalhaoAnalysisResult(
      areaTotalAmostradaHa: areaTotalAmostradaHa,
      totalArvoresAmostradas: todasAsArvores.length,
      mediaCap: mediaCap,
      mediaAltura: mediaAltura,
      areaBasalPorHectare: areaBasalPorHectare,
      volumePorHectare: volumePorHectare,
      arvoresPorHectare: arvoresPorHectare,
      warnings: warnings,
      insights: insights,
      recommendations: recommendations,
    );
  }

  /// Simula um desbaste seletivo (removendo as árvores mais finas) e retorna as métricas do talhão PÓS-DESBASTE.
  TalhaoAnalysisResult simularDesbaste(List<Parcela> parcelasOriginais, double porcentagemRemocao) {
    if (parcelasOriginais.isEmpty || porcentagemRemocao <= 0) {
      return getTalhaoInsights(parcelasOriginais);
    }
    
    final List<Arvore> todasAsArvores = parcelasOriginais.expand((p) => p.arvores).toList();
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.status == StatusArvore.normal).toList();
    
    // Se não houver árvores vivas, não há o que simular.
    if (arvoresVivas.isEmpty) {
      return getTalhaoInsights(parcelasOriginais);
    }

    arvoresVivas.sort((a, b) => a.cap.compareTo(b.cap));
    
    final int quantidadeRemover = (arvoresVivas.length * (porcentagemRemocao / 100)).floor();
    final List<Arvore> arvoresRemanescentes = arvoresVivas.sublist(quantidadeRemover);
    
    // Criamos uma "pseudo-parcela" com os dados agregados para recalcular os insights
    // <<< CORREÇÃO APLICADA AQUI >>>
    final Parcela pseudoParcelaPosDesbaste = Parcela(
      // --- Dados obrigatórios ---
      nomeFazenda: parcelasOriginais.first.nomeFazenda,
      nomeTalhao: parcelasOriginais.first.nomeTalhao,
      idParcela: "Simulação Pós-Desbaste", // Um ID genérico para a simulação
      areaMetrosQuadrados: parcelasOriginais.map((p) => p.areaMetrosQuadrados).reduce((a,b) => a+b),
      status: parcelasOriginais.first.status, // Podemos usar o status da primeira parcela como base

      // --- Lista de árvores atualizada ---
      arvores: arvoresRemanescentes, // Apenas as árvores que sobraram
    );

    // Recalcula todos os insights usando a nova "pseudo-parcela" que representa o estado futuro.
    return getTalhaoInsights([pseudoParcelaPosDesbaste]);
  }

  /// Classifica as árvores de um talhão por finalidade comercial e calcula o rendimento por hectare.
  RendimentoTalhaoResult analisarRendimentoPorHectare(List<Parcela> parcelasDoTalhao) {
    final List<Arvore> todasAsArvores = parcelasDoTalhao.expand((p) => p.arvores).toList();
    final double areaTotalAmostradaM2 = parcelasDoTalhao.map((p) => p.areaMetrosQuadrados).reduce((a, b) => a + b);
    
    final Map<FinalidadeMadeira, double> volumeTotalPorFinalidade = { for (var f in FinalidadeMadeira.values) f: 0.0 };
    final Map<FinalidadeMadeira, int> contagemPorFinalidade = { for (var f in FinalidadeMadeira.values) f: 0 };

    if (todasAsArvores.isEmpty || areaTotalAmostradaM2 == 0) {
      return RendimentoTalhaoResult(volumePorHectare: volumeTotalPorFinalidade, arvoresPorHectare: contagemPorFinalidade);
    }

    final double areaTotalAmostradaHa = areaTotalAmostradaM2 / 10000;
    final List<Arvore> arvoresVivas = todasAsArvores.where((a) => a.status == StatusArvore.normal).toList();
    final double mediaAltura = _calculateAverage(arvoresVivas.map((a) => a.altura).whereType<double>().toList());

    for (var arv in arvoresVivas) {
      double volumeArvore = _estimateVolume(arv.cap, arv.altura ?? mediaAltura);
      
      // Classificação (pode ser mais complexa, aqui é um exemplo)
      // Uma árvore pode se encaixar em mais de uma categoria, a lógica de negócio define a prioridade
      if (arv.cap >= 20 && (arv.altura ?? mediaAltura) >= 12) { // Prioridade para Serraria
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
    
    // Extrapola para hectare
    final Map<FinalidadeMadeira, double> volumePorHectare = {};
    final Map<FinalidadeMadeira, int> arvoresPorHectare = {};

    for (var finalidade in volumeTotalPorFinalidade.keys) {
      volumePorHectare[finalidade] = (volumeTotalPorFinalidade[finalidade] ?? 0) / areaTotalAmostradaHa;
      arvoresPorHectare[finalidade] = ((contagemPorFinalidade[finalidade] ?? 0) / areaTotalAmostradaHa).round();
    }
    
    return RendimentoTalhaoResult(volumePorHectare: volumePorHectare, arvoresPorHectare: arvoresPorHectare);
  }

  // --- MÉTODOS AUXILIARES PRIVADOS ---

  /// Calcula a área basal (G) em m² para uma única árvore.
  double _areaBasalPorArvore(double cap) {
    if (cap <= 0) return 0;
    final double dap = cap / pi;
    return (pi * pow(dap, 2)) / 40000;
  }

  /// Estima o volume de uma árvore usando a fórmula de fator de forma.
  /// Futuramente, será substituído pela chamada ao PredictionService.
  double _estimateVolume(double cap, double altura) {
    if (cap <= 0 || altura <= 0) return 0;
    final areaBasal = _areaBasalPorArvore(cap);
    return areaBasal * altura * FATOR_DE_FORMA;
  }

  /// Calcula a média de uma lista de números, tratando listas vazias.
  double _calculateAverage(List<double> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a + b) / numbers.length;
  }
}