import 'package:flutter/material.dart';

/// Conteúdo educativo por distúrbio digestivo: o que o ingrediente faz no
/// organismo de quem tem a condição, sintomas típicos e ícone visual.
///
/// Fonte das informações: literatura clínica geral (revisar com nutricionista
/// para validação científica antes de publicação acadêmica).
class DisorderExplanation {
  final IconData icon;
  final String shortReason; // "Pode causar X, Y, Z" — uma linha
  final String detail;      // Parágrafo com mecanismo + recomendação

  const DisorderExplanation({
    required this.icon,
    required this.shortReason,
    required this.detail,
  });
}

const Map<String, DisorderExplanation> disorderExplanations = {
  'Intolerância à Lactose': DisorderExplanation(
    icon: Icons.local_drink_outlined,
    shortReason:
        'Pode causar inchaço, gases, cólicas abdominais e diarreia.',
    detail:
        'Pessoas com intolerância à lactose têm produção reduzida da enzima '
        'lactase, que quebra o açúcar do leite. A lactose não digerida fermenta '
        'no intestino, causando os sintomas. A gravidade varia conforme a '
        'quantidade ingerida e a sensibilidade individual.',
  ),
  'Doença Celíaca': DisorderExplanation(
    icon: Icons.grass_outlined,
    shortReason:
        'Desencadeia reação autoimune que danifica o intestino delgado.',
    detail:
        'O glúten (presente em trigo, cevada e centeio) provoca uma reação '
        'imunológica que destrói as vilosidades intestinais, comprometendo a '
        'absorção de nutrientes. Sintomas incluem diarreia crônica, dor '
        'abdominal, fadiga, perda de peso e deficiências nutricionais. Mesmo '
        'pequenas quantidades devem ser evitadas estritamente.',
  ),
  'Síndrome do Intestino Irritável (SII)': DisorderExplanation(
    icon: Icons.sentiment_dissatisfied_outlined,
    shortReason:
        'Carboidratos fermentáveis podem agravar gases, distensão e dor.',
    detail:
        'Pacientes com SII costumam ser sensíveis aos FODMAPs (oligossacarídeos, '
        'dissacarídeos, monossacarídeos e polióis fermentáveis). Esses '
        'carboidratos são mal absorvidos no intestino delgado e fermentam no '
        'cólon, causando distensão, gases e alterações no hábito intestinal. '
        'A tolerância varia entre indivíduos.',
  ),
  'Doença de Crohn': DisorderExplanation(
    icon: Icons.healing_outlined,
    shortReason:
        'Pode agravar inflamação intestinal e desencadear crises.',
    detail:
        'A Doença de Crohn é uma inflamação crônica que pode afetar qualquer '
        'parte do trato digestivo. Alimentos ultraprocessados, gorduras trans, '
        'álcool e cafeína podem agravar a inflamação durante crises. Lactose e '
        'glúten são frequentemente mal tolerados, especialmente em períodos de '
        'atividade da doença.',
  ),
  'Colite Ulcerativa': DisorderExplanation(
    icon: Icons.healing_outlined,
    shortReason:
        'Pode irritar o cólon e piorar diarreia e sangramento.',
    detail:
        'A colite ulcerativa causa inflamação e úlceras no intestino grosso. '
        'Pimenta, álcool, cafeína, gorduras trans e aromatizantes artificiais '
        'podem irritar a mucosa intestinal e agravar sintomas como diarreia '
        'sanguinolenta, urgência e dor abdominal, especialmente durante crises.',
  ),
  'Alergia à Proteína do Leite (APLV)': DisorderExplanation(
    icon: Icons.warning_amber_outlined,
    shortReason:
        'Pode causar reação alérgica sistêmica — risco de anafilaxia.',
    detail:
        'Diferente da intolerância à lactose, a APLV é uma reação imunológica '
        'às proteínas do leite (caseína e proteínas do soro). Sintomas variam '
        'de urticária e vômitos a anafilaxia, uma reação grave que pode ser '
        'fatal. Mesmo traços devem ser evitados — leia rótulos com atenção.',
  ),
  'Alergia ao Ovo': DisorderExplanation(
    icon: Icons.warning_amber_outlined,
    shortReason:
        'Pode causar reação alérgica — risco de anafilaxia em casos graves.',
    detail:
        'A alergia ao ovo é mais comum em crianças, mas pode persistir na vida '
        'adulta. As proteínas da clara (ovoalbumina, ovomucoide) são as '
        'principais causadoras. Sintomas incluem urticária, vômitos, dificuldade '
        'respiratória e anafilaxia. Atenção a derivados como albumina e '
        'lecitina de ovo.',
  ),
  'Alergia ao Amendoim': DisorderExplanation(
    icon: Icons.warning_amber_outlined,
    shortReason:
        'Reação potencialmente grave — alto risco de anafilaxia.',
    detail:
        'A alergia ao amendoim é uma das mais graves e persistentes. Mesmo '
        'quantidades mínimas (incluindo traços por contaminação cruzada) podem '
        'desencadear anafilaxia. Evite produtos sem rotulagem clara e atenção '
        'aos avisos "pode conter amendoim".',
  ),
  'Alergia à Soja': DisorderExplanation(
    icon: Icons.warning_amber_outlined,
    shortReason:
        'Pode causar reação alérgica — atenção a derivados ocultos.',
    detail:
        'A soja está em muitos produtos industrializados como lecitina (E322), '
        'proteína isolada, óleo e molhos. Reações vão de leves (coceira, '
        'urticária) a graves (anafilaxia). A lecitina de soja é o ponto de '
        'atenção mais comum em rótulos.',
  ),
  'Intolerância à Frutose': DisorderExplanation(
    icon: Icons.local_drink_outlined,
    shortReason:
        'Pode causar dor abdominal, gases e diarreia.',
    detail:
        'A má absorção de frutose impede que ela seja digerida no intestino '
        'delgado. Ela então fermenta no cólon, causando os sintomas. Atenção '
        'especial a mel, agave, xaropes de milho e frutose, e sucos de frutas '
        'concentrados.',
  ),
  'FODMAP Sensível': DisorderExplanation(
    icon: Icons.sentiment_dissatisfied_outlined,
    shortReason:
        'Pode causar fermentação intestinal excessiva e desconforto.',
    detail:
        'A dieta low-FODMAP restringe carboidratos fermentáveis que causam '
        'distensão e gases em pessoas sensíveis. Inclui lactose, frutose em '
        'excesso, polióis (sorbitol, manitol), frutanos (em trigo, cebola, '
        'alho) e galactanos. A tolerância é individual — recomenda-se '
        'acompanhamento nutricional para reintrodução gradual.',
  ),
  'Refluxo Gastroesofágico (DRGE)': DisorderExplanation(
    icon: Icons.local_fire_department_outlined,
    shortReason:
        'Pode relaxar o esfíncter esofágico e provocar refluxo ácido.',
    detail:
        'Cafeína, chocolate, hortelã, álcool e gorduras pesadas relaxam o '
        'esfíncter esofágico inferior, facilitando o refluxo do ácido '
        'estomacal. Pimenta e tomate podem irritar diretamente a mucosa '
        'esofágica. Resultado: azia, regurgitação, tosse noturna e desconforto '
        'após as refeições.',
  ),
  'Alérgeno personalizado': DisorderExplanation(
    icon: Icons.warning_amber_outlined,
    shortReason:
        'Item incluído manualmente no seu perfil para monitoramento.',
    detail:
        'Você marcou este ingrediente como algo a evitar. O app o sinaliza '
        'sempre que aparecer em um rótulo. Se a reação for grave ou recorrente, '
        'consulte um médico ou nutricionista para investigação adequada.',
  ),
};
