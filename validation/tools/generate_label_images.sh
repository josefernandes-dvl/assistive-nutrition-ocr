#!/usr/bin/env bash
# Gera o corpus de imagens de rótulo usado pelo CA02 (taxa de leitura do OCR) e
# pelo CA07 (tempo de OCR).
#
# As imagens são RENDERIZAÇÕES SINTÉTICAS de listas de ingredientes reais de
# produtos brasileiros, degradadas para reproduzir as condições de captura que
# a literatura aponta como críticas: rotação, desfoque, ruído, baixo contraste,
# compressão, rótulo escuro, perspectiva, fonte pequena e iluminação desigual.
#
# Não substituem fotografias de rótulos reais — ver validation/README.md. O
# corpus existe para tornar a medição reprodutível em CI, onde não há câmera.
#
# Uso: bash validation/tools/generate_label_images.sh
# Requer: ImageMagick (convert)

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAIDA="$(cd "$AQUI/.." && pwd)/labels"
FONTE="DejaVu-Sans"
FONTE_COND="DejaVu-Sans-Condensed"

mkdir -p "$SAIDA"
rm -f "$SAIDA"/L*.png "$SAIDA"/L*.jpg

# render <arquivo> <pointsize> <cor_texto> <cor_fundo> <fonte> <linha...>
render() {
  local arquivo="$1" ; shift
  local pointsize="$1" ; shift
  local cor_texto="$1" ; shift
  local cor_fundo="$1" ; shift
  local fonte="$1" ; shift

  local args=(-size 1200x560 "xc:${cor_fundo}" -font "$fonte" \
              -pointsize "$pointsize" -fill "$cor_texto")
  local y=70
  for linha in "$@"; do
    args+=(-annotate "+45+${y}" "$linha")
    y=$((y + pointsize + 16))
  done
  convert "${args[@]}" "$arquivo"
}

# --- L01 · leitura limpa (controle) ------------------------------------------
render "$SAIDA/L01.png" 30 black white "$FONTE" \
  "INGREDIENTES: FARINHA DE TRIGO ENRIQUECIDA COM FERRO" \
  "E ÁCIDO FÓLICO, AÇÚCAR, GORDURA VEGETAL, AMIDO DE" \
  "MILHO, SORO DE LEITE EM PÓ, SAL, EMULSIFICANTE" \
  "LECITINA DE SOJA E AROMATIZANTE." \
  "CONTÉM GLÚTEN, LEITE E SOJA."

# --- L02 · rotação leve ------------------------------------------------------
render "$SAIDA/_tmp.png" 30 black white "$FONTE" \
  "INGREDIENTES: LEITE INTEGRAL, AÇÚCAR E LACTOSE." \
  "NÃO CONTÉM GLÚTEN." \
  "INFORMAÇÃO NUTRICIONAL POR PORÇÃO DE 20 G."
convert "$SAIDA/_tmp.png" -background white -rotate 3 "$SAIDA/L02.png"

# --- L03 · rotação maior sobre fundo acinzentado -----------------------------
render "$SAIDA/_tmp.png" 30 "#1a1a1a" "#e8e6e0" "$FONTE" \
  "INGREDIENTES: AVEIA EM FLOCOS, XAROPE DE GLICOSE," \
  "AMENDOINS TORRADOS, MEL, ÓLEO DE GIRASSOL, SAL." \
  "PODE CONTER TRAÇOS DE LEITE E SOJA."
convert "$SAIDA/_tmp.png" -background "#e8e6e0" -rotate -6 "$SAIDA/L03.png"

# --- L04 · desfoque (foco imperfeito) ----------------------------------------
render "$SAIDA/_tmp.png" 32 black white "$FONTE" \
  "INGREDIENTES: ÁGUA, SHOYU (ÁGUA, SAL, GRÃO DE SOJA," \
  "TRIGO), AÇÚCAR, VINAGRE DE ÁLCOOL, AMIDO MODIFICADO," \
  "CONSERVADOR BENZOATO DE SÓDIO."
convert "$SAIDA/_tmp.png" -blur 0x1.4 "$SAIDA/L04.png"

# --- L05 · ruído de sensor (pouca luz) ---------------------------------------
render "$SAIDA/_tmp.png" 32 black white "$FONTE" \
  "INGREDIENTES: ÓLEO DE SOJA, ÁGUA, OVOS PASTEURIZADOS," \
  "VINAGRE, AÇÚCAR, SAL, SUCO DE LIMÃO, ACIDULANTE" \
  "ÁCIDO CÍTRICO. PODE CONTER LEITE."
convert "$SAIDA/_tmp.png" -attenuate 0.45 +noise Gaussian "$SAIDA/L05.png"

# --- L06 · baixo contraste (texto cinza em embalagem clara) ------------------
render "$SAIDA/L06.png" 32 "#8a8a8a" "#f2f2f2" "$FONTE" \
  "INGREDIENTES: QUEIJO PARMESÃO (LEITE PASTEURIZADO," \
  "SAL, COALHO, FERMENTO LÁCTEO), ANTIUMECTANTE AMIDO" \
  "DE MANDIOCA."

# --- L07 · compressão agressiva ---------------------------------------------
render "$SAIDA/_tmp.png" 30 black white "$FONTE" \
  "INGREDIENTES: ÁGUA GASEIFICADA, AÇÚCAR, EXTRATO DE" \
  "NOZ DE COLA, CAFEÍNA, CORANTE CARAMELO IV," \
  "ACIDULANTE ÁCIDO FOSFÓRICO, AROMATIZANTE NATURAL."
convert "$SAIDA/_tmp.png" -quality 25 "$SAIDA/L07.jpg"

# --- L08 · rótulo escuro (texto claro sobre fundo escuro) --------------------
render "$SAIDA/L08.png" 32 "#f5f5f5" "#141414" "$FONTE" \
  "INGREDIENTES: ÁGUA, MALTE DE CEVADA, CEREAIS NÃO" \
  "MALTEADOS, LÚPULO E ANTIOXIDANTE INS 224." \
  "CONTÉM GLÚTEN."

# --- L09 · perspectiva (foto de lado) ---------------------------------------
render "$SAIDA/_tmp.png" 34 black white "$FONTE" \
  "INGREDIENTES: EDULCORANTES SORBITOL E MALTITOL," \
  "ÁGUA, ACIDULANTE ÁCIDO CÍTRICO, AROMA IDÊNTICO" \
  "AO NATURAL."
convert "$SAIDA/_tmp.png" -virtual-pixel white \
  -distort Perspective '0,0 30,18  1200,0 1170,0  0,560 0,545  1200,560 1185,560' \
  "$SAIDA/L09.png"

# --- L10 · fonte pequena (foto de longe) ------------------------------------
render "$SAIDA/L10.png" 19 black white "$FONTE" \
  "INGREDIENTES: LEITE PASTEURIZADO DESNATADO, LEITE EM PÓ DESNATADO E FERMENTO LÁCTEO." \
  "INFORMAÇÃO NUTRICIONAL: VALOR ENERGÉTICO 60 KCAL POR PORÇÃO." \
  "CONSERVAR SOB REFRIGERAÇÃO ENTRE 1 °C E 10 °C."

# --- L11 · iluminação desigual (sombra em um dos lados) ---------------------
render "$SAIDA/_tmp.png" 32 black white "$FONTE" \
  "INGREDIENTES: AÇÚCAR, MANTEIGA DE CACAU, LEITE EM PÓ" \
  "INTEGRAL, MASSA DE CACAU, EMULSIFICANTE LECITINA DE" \
  "SOJA, AROMATIZANTE. CONTÉM DERIVADOS DE LEITE E SOJA."
convert "$SAIDA/_tmp.png" \
  \( -size 1200x560 gradient:white-gray40 -rotate 90 \) \
  -compose multiply -composite "$SAIDA/L11.png"

# --- L12 · fonte condensada e linhas apertadas ------------------------------
render "$SAIDA/L12.png" 26 black white "$FONTE_COND" \
  "INGREDIENTES: ÓLEOS VEGETAIS LÍQUIDO E INTERESTERIFICADO DE SOJA, ÁGUA, SAL," \
  "EMULSIFICANTES LECITINA DE SOJA E MONO E DIGLICERÍDEOS DE ÁCIDOS GRAXOS," \
  "CONSERVADOR BENZOATO DE SÓDIO, AROMATIZANTE, CORANTE URUCUM."

rm -f "$SAIDA/_tmp.png"
echo "Corpus gerado em $SAIDA:"
ls -1 "$SAIDA" | grep -E '^L[0-9]+\.(png|jpg)$'
