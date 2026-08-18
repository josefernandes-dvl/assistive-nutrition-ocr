/// Estruturas de alerta derivadas do texto do rótulo, produzidas pela análise
/// on-device. Ficam num modelo próprio (e não no analisador) porque são
/// **persistidas** junto ao resultado, para sobreviver ao histórico.

/// Aviso de "contém traços / pode conter" relevante ao perfil — presença
/// POSSÍVEL (contaminação cruzada).
class TraceWarning {
  final String term;
  final List<String> disorders;
  const TraceWarning({required this.term, required this.disorders});

  Map<String, dynamic> toJson() => {
        'term': term,
        'disorders': disorders,
      };

  factory TraceWarning.fromJson(Map<String, dynamic> json) => TraceWarning(
        term: json['term'] as String? ?? '',
        disorders: (json['disorders'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

/// Declaração direta "Contém X" do rótulo, relevante ao perfil. Diferente de
/// [TraceWarning]: representa presença DECLARADA pelo fabricante — alerta de
/// nível mais alto (presença confirmada, não mera possibilidade).
class ContainsDeclaration {
  final String term;
  final List<String> disorders;
  const ContainsDeclaration({required this.term, required this.disorders});

  Map<String, dynamic> toJson() => {
        'term': term,
        'disorders': disorders,
      };

  factory ContainsDeclaration.fromJson(Map<String, dynamic> json) =>
      ContainsDeclaration(
        term: json['term'] as String? ?? '',
        disorders: (json['disorders'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
