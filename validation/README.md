# Validação dos Critérios de Aceitação

Este diretório reúne os **artefatos de medição** dos critérios da [ERS](../docs/REQUIREMENTS.md#5-critérios-de-aceitação) que exigem corpus ou instrumentação: CA02, CA03, CA07 e CA12. Os demais critérios são verificados diretamente pelas suítes de teste (ver tabela ao final).

O princípio adotado é o da Seção 5 da ERS: **nenhum critério é dado como atendido sem evidência reproduzível**. Cada número abaixo sai de um comando que qualquer pessoa pode repetir.

## Como reproduzir

```bash
# Backend — inclui recall (CA03), paridade RN02 e latência do barcode (CA12)
cd backend && npm install && npm test

# App — inclui contraste (CA04), acessibilidade (CA06), persistência (CA01/CA05),
# privacidade (CA08), disclaimer (CA15), recall (CA03) e OCR (CA02/CA07)
cd mobile && flutter pub get && flutter test

# Regerar o corpus de imagens (requer ImageMagick)
bash validation/tools/generate_label_images.sh

# Conferir o contrato real da Open Food Facts (requer rede)
cd backend && RUN_LIVE_OFF=1 node --test test/products.test.js
```

O OCR de desktop exige `tesseract-ocr` e `tesseract-ocr-por`. Sem eles, os testes de CA02/CA07 são **pulados** (não falsamente aprovados).

## Artefatos

| Arquivo | Conteúdo |
|---|---|
| [`recall_corpus.json`](recall_corpus.json) | 20 rótulos positivos + 5 controles negativos, com perfil e gatilho anotados. Consumido pelo app (`mobile/test/recall_test.dart`) e pelo backend (`backend/test/recall.test.js`). |
| [`disorder_triggers.json`](disorder_triggers.json) | Tabela canônica da RN02. As duas cópias em código são verificadas contra ela (teste de paridade). |
| [`labels/`](labels/) | 12 imagens de rótulo em condições variadas + `manifest.json` com os termos esperados. |
| [`tools/generate_label_images.sh`](tools/generate_label_images.sh) | Gerador reprodutível do corpus de imagens. |

## Resultados medidos

Execução de **2026-07-22**, em Linux x86-64, Flutter 3.41.5 / Dart 3.11.3, Node.js 20.20.2, Tesseract 5.3.4 (`por`+`eng`).

| Critério | Métrica | Limiar | Medido | Situação |
|---|---|---|---|:---:|
| **CA02** | Imagens com texto não vazio | ≥ 9 em 10 | **12/12 (100%)** | ✔ |
| **CA02** (complementar) | Imagens com ingrediente extraído | — | 12/12 | ✔ |
| **CA02** (complementar) | Imagens com o alerta esperado | ≥ 85% | 12/12 | ✔ |
| **CA03** | Recall no app (pipeline OCR → alerta) | ≥ 85% | **100% (20/20)** | ✔ |
| **CA03** | Recall no backend (mesma lista de ingredientes) | ≥ 85% | **100% (20/20)** | ✔ |
| **CA03** | Falsos positivos nos controles negativos | 0 | **0/5** | ✔ |
| **CA07** | Mediana do tempo de OCR (20 medições) | ≤ 5 s | **0,37 s** (mín 0,31 s · máx 0,61 s) | ✔ |
| **CA12** | `GET /api/products/barcode/:code` com stub | ≤ 5 s | **~150 ms** | ✔ |
| **CA12** | `POST /api/ocr/analyze` com barcode | ≤ 5 s | **~186 ms** | ✔ |
| **CA12** | Consulta real à Open Food Facts (opcional) | ≤ 5 s | **1376 ms** | ✔ |

### O que estas medições **não** provam

Registrar o alcance da evidência é parte do critério — sem isso o número vira propaganda.

1. **O corpus de imagens é sintético.** São renderizações de listas de ingredientes reais, degradadas para reproduzir rotação, desfoque, ruído, baixo contraste, compressão, rótulo escuro, perspectiva, fonte pequena e iluminação desigual. Elas **não substituem fotografias de rótulos reais**, que trazem curvatura de embalagem, reflexo especular e fundo poluído. A validação com fotografias e com participantes reais continua pendente e é o próximo passo do plano de trabalho.
2. **CA07 não foi medido no aparelho de referência.** O RNF01 fala em Android de gama média com Google ML Kit; a medição acima é do pipeline **Tesseract em desktop** (ADR-009), que é o motor disponível em CI. O número mostra que o critério é atendido pelo motor medido — não que o ML Kit em Snapdragon 6xx entregue o mesmo. Rodar a mesma medição em aparelho exige um teste de integração no dispositivo.
3. **CA12 mede o servidor, não a ponta a ponta no supermercado.** O tempo do app soma a latência do celular à rede e, no *free tier*, o *cold start* de até ~30 s (RA-04). A cláusula "com servidor ativo" do critério delimita exatamente isso.
4. **O corpus de recall foi escrito pelos autores.** Os textos seguem a redação típica de rótulos brasileiros e incluem casos difíceis (sinônimo técnico, gatilho oculto, plural, erro de OCR, armadilhas de substring), mas um corpus de autoria própria mede a regra contra a intenção de quem a escreveu. Corpus independente é trabalho futuro.

## Defeitos encontrados pela instrumentação

As medições não só registraram o estado: elas revelaram três defeitos reais, corrigidos nesta rodada.

| # | Defeito | Como apareceu | Correção |
|---|---|---|---|
| 1 | **O OCR de desktop falhava em imagens de 1 canal.** Numa imagem em escala de cinza, os canais verde e azul valem zero e a luminância ficava em ~30% do valor real, então a binarização devolvia uma imagem toda preta. | CA02 mediu 1/12 imagens com texto, enquanto o `tesseract` puro lia as mesmas imagens perfeitamente. | Conversão para 3 canais antes de qualquer cálculo de luminância (`ocr_service.dart`). |
| 2 | **O pré-processamento piorava o resultado e dominava o tempo.** Quatro execuções do Tesseract sobre variantes binarizadas custavam ~5 s e reconheciam menos que a imagem original. | CA02 subiu só para 5/12 após a correção nº 1; CA07 media mediana de 5,11 s. | Ler a imagem original primeiro (o Tesseract já binariza por Otsu) e só cair no pipeline de resgate quando nenhum termo do dicionário é reconhecido. Resultado: 12/12 e mediana de 0,37 s. |
| 3 | **A correção por dicionário inventava ingrediente.** `sorbato de potássio` (conservante inofensivo) era reescrito como **sorbitol** e disparava alerta de FODMAP; `ácido fólico` virava `amido fólico`. | Inspeção do corpus de recall, item P17. | A correção palavra a palavra passou a exigir evidência de erro de leitura (dígito no meio de letras). A correção da expressão inteira, que cobre `giúten` → `glúten`, continua ativa. |

## Cobertura dos demais critérios

| Critério | Verificado por |
|---|---|
| CA01, CA05 | `mobile/test/persistence_test.dart` (reabertura do app com o mesmo armazenamento) |
| CA04 | `mobile/test/contrast_audit_test.dart` (paleta + 10 telas renderizadas + varredura do código-fonte) |
| CA06 | `mobile/test/accessibility_test.dart` (árvore de semântica + diretrizes do Flutter) |
| CA08 | `mobile/test/privacy_flow_test.dart` e `persistence_test.dart` |
| CA09 | `backend/test/products.test.js` (base externa em 503) |
| CA10 | `mobile/test/ocr_corpus_test.dart` e a regra da tela de captura |
| CA11, CA16 | `mobile/test/matching_test.dart` e `backend/test/matching.test.js` |
| CA13 | `mobile/test/matching_test.dart` (avisos de traço) |
| CA14 | `mobile/test/matching_test.dart` (correção por dicionário) |
| CA15 | `mobile/test/accessibility_test.dart` |
| RN02 (paridade) | `backend/test/parity.test.js` e `mobile/test/trigger_parity_test.dart` |
