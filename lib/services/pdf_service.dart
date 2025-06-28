import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  Future<void> gerarPlanoCubagemPdf({
    required BuildContext context,
    required String nomeFazenda,
    required String nomeTalhao,
    required Map<String, int> planoDeCubagem,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => _buildHeader(nomeFazenda, nomeTalhao),
        footer: (pw.Context context) => _buildFooter(),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 20),
            pw.Text(
              'Plano de Cubagem Estratificada por Classe Diamétrica',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(height: 20),
            _buildTabelaPlano(planoDeCubagem),
          ];
        },
      ),
    );

    await _salvarEAbriPdf(context, pdf, 'plano_cubagem_${nomeTalhao.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf');
  }

  pw.Widget _buildHeader(String nomeFazenda, String nomeTalhao) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 20.0),
      padding: const pw.EdgeInsets.only(bottom: 8.0),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('GeoForest Coletor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 5),
              pw.Text('Fazenda: $nomeFazenda'),
              pw.Text('Talhão: $nomeTalhao'),
            ],
          ),
          pw.Text('Data: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // <<< CORREÇÃO PRINCIPAL AQUI >>>
  // Trocamos `Table.fromTextArray` por `Table` para ter mais controle de estilo.
  pw.Widget _buildTabelaPlano(Map<String, int> plano) {
    final headers = ['Classe Diamétrica (CAP)', 'Nº de Árvores para Cubar'];
    
    if (plano.isEmpty) {
      return pw.Center(child: pw.Text("Nenhum dado para gerar o plano."));
    }

    final data = plano.entries.map((entry) => [entry.key, entry.value.toString()]).toList();
    final total = plano.values.fold(0, (a, b) => a + b);
    data.add(['Total', total.toString()]);

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        // Linha do Cabeçalho
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: headers.map((header) => pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(header, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
              )).toList(),
        ),
        // Linhas de Dados
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final rowData = entry.value;
          final bool isLastRow = index == data.length - 1;

          return pw.TableRow(
            children: rowData.asMap().entries.map((cellEntry) {
              final colIndex = cellEntry.key;
              final cellText = cellEntry.value;
              return pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  cellText,
                  textAlign: colIndex == 1 ? pw.TextAlign.center : pw.TextAlign.left,
                  style: isLastRow ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : const pw.TextStyle(),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'Documento gerado pelo Analista GeoForest',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    );
  }

  Future<void> _salvarEAbriPdf(BuildContext context, pw.Document pdf, String nomeArquivo) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$nomeArquivo';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o PDF. Salvo em: $path')));
        }
      }
    } catch (e) {
      debugPrint("Erro ao salvar/abrir PDF: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar o PDF: $e')));
      }
    }
  }
}