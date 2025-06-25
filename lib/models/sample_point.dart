// lib/models/sample_point.dart

import 'package:latlong2/latlong.dart';

// 1. Criamos um enum para os status da parcela. É mais seguro e legível que usar Strings.
enum SampleStatus {
  untouched, // Branca
  open,      // Laranja Claro
  completed, // Verde
  exported,  // Azul
}

class SamplePoint {
  final int id;
  final LatLng position;
  final SampleStatus status; // 2. Adicionamos o campo de status ao modelo.

  SamplePoint({
    required this.id,
    required this.position,
    this.status = SampleStatus.untouched, // 3. O status padrão é 'untouched' (branca).
  });

  // 4. Um método 'copyWith' é essencial para atualizar o estado de forma imutável.
  SamplePoint copyWith({
    int? id,
    LatLng? position,
    SampleStatus? status,
  }) {
    return SamplePoint(
      id: id ?? this.id,
      position: position ?? this.position,
      status: status ?? this.status,
    );
  }
}