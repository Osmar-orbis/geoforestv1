// lib/services/validation_service.dart (VERSÃO FINAL CORRIGIDA)
import 'dart:math';
import 'package:geoforestcoletor/models/arvore_model.dart';

class ValidationResult {
  final bool isValid;
  final List<String> warnings;
  ValidationResult({this.isValid = true, this.warnings = const []});
}

class ValidationService {
  ValidationResult validateSingleTree(Arvore arvore) {
    final List<String> warnings = [];
    if (arvore.cap <= 5.0) {
      warnings.add("CAP de ${arvore.cap} cm é muito baixo. Verifique.");
    }
    if (arvore.cap > 400.0) {
      warnings.add("CAP de ${arvore.cap} cm é fisicamente improvável. Verifique.");
    }
    if (arvore.altura != null && arvore.altura! > 70) {
      warnings.add("Altura de ${arvore.altura}m é extremamente rara. Confirme.");
    }
    if (arvore.altura != null && arvore.cap > 150 && arvore.altura! < 10) {
        warnings.add("Relação CAP/Altura incomum: ${arvore.cap} cm de CAP com apenas ${arvore.altura}m de altura.");
    }
    return ValidationResult(isValid: warnings.isEmpty, warnings: warnings);
  }

  ValidationResult validateParcela(List<Arvore> arvores) {
    if (arvores.length < 10) return ValidationResult();
    
    final List<String> warnings = [];

    double somaCap = arvores.map((a) => a.cap).reduce((a, b) => a + b);
    double mediaCap = somaCap / arvores.length;
    
    // LINHA CORRIGIDA: Adicionado .toDouble() no final
    double somaDiferencasQuadrado = arvores.map((a) => pow(a.cap - mediaCap, 2)).reduce((a, b) => a + b).toDouble();
    
    double desvioPadraoCap = sqrt(somaDiferencasQuadrado / (arvores.length - 1));
    
    for (final arvore in arvores) {
      if ((arvore.cap - mediaCap).abs() > 2.5 * desvioPadraoCap) {
        warnings.add("Árvore Linha ${arvore.linha}/Pos ${arvore.posicaoNaLinha}: O CAP de ${arvore.cap}cm é um outlier estatístico (média: ${mediaCap.toStringAsFixed(1)}cm).");
      }
    }
    
    return ValidationResult(isValid: warnings.isEmpty, warnings: warnings);
  }
}