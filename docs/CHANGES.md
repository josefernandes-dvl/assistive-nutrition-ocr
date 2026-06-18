# NutriScan — Spec Técnico das Mudanças

> Documento consolidado de todas as alterações feitas durante a evolução do
> projeto, do estado inicial à versão atual com APK Android funcional.

## Índice

1. [Backend (Node + Express)](#backend)
2. [Mobile (Flutter)](#mobile)
3. [Android (build + runtime)](#android)
4. [Documentação e infra](#docs-infra)
5. [Testes automatizados](#testes)
6. [CI/CD](#cicd)
7. [Decisões arquiteturais](#arq)

---

## <a name="backend"></a>1. Backend (Node + Express)

### 1.1 Estrutura nova
```
backend/
├── src/
│   ├── data/disorderTriggers.js        ← fonte única triggers
│   ├── models/
│   │   ├── ScanResult.js                ← Mongoose
│   │   └── UserProfile.js               ← Mongoose
│   ├── routes/
│   │   ├── ocr.js                       ← POST /api/ocr/analyze
│   │   ├── products.js                  ← GET /api/products/barcode/:code
│   │   ├── profiles.js                  ← CRUD perfil
│   │   └── scans.js                     ← histórico
│   ├── services/
│   │   ├── ingredientAnalyzer.js        ← correlação + severidade
│   │   └── openFoodFacts.js             ← wrapper OFF + cache
│   └── server.js                        ← bootstrap + CORS + Mongo opcional
└── test/
    ├── analyzer.test.js                 ← 9 testes unitários
    └── routes.test.js                   ← 3 testes de integração
```

### 1.2 Endpoints

| Método | Rota | Função |
|---|---|---|
| `GET`  | `/api/health`                       | Status + estado do Mongo |
| `POST` | `/api/ocr/analyze`                  | Analisa ingredientes vs perfil; aceita `barcode` opcional |
| `GET`  | `/api/products/barcode/:code`       | Proxy Open Food Facts com cache |
| `GET`  | `/api/products/search?q=`           | Busca produtos por texto |
| `GET`  | `/api/scans` / `POST` / `:id`       | Histórico (requer Mongo) |
| `GET`  | `/api/profiles/current` / `POST`    | Perfil único (requer Mongo) |

### 1.3 Comportamentos críticos

- **Mongo opcional**: servidor sobe mesmo sem Mongo. `/api/ocr/*` e `/api/products/*` funcionam normalmente; só `/api/scans` e `/api/profiles` ficam indisponíveis.
- **Cache OFF**: produtos cacheados por 1h em memória (`node-cache`); buscas por texto por 5min.
- **CORS aberto** com preflight `OPTIONS` retornando 204.
- **EADDRINUSE tratado**: se a porta estiver em uso, mensagem amigável e exit 1 explícito.
- **Política de fonte de ingredientes**: se o cliente envia `ingredients`, eles têm prioridade sobre a lista da OFF (que pode estar em outro idioma). OFF só é fallback quando cliente envia apenas barcode.

### 1.4 Dependências adicionadas
- `axios` ^1.16.1 — chamadas à Open Food Facts
- `node-cache` ^5.1.2 — cache em memória

---

## <a name="mobile"></a>2. Mobile (Flutter)

### 2.1 Pacotes adicionados ao `pubspec.yaml`
| Pacote | Versão | Uso |
|---|---|---|
| `mobile_scanner` | ^5.2.3 | Leitor de código de barras (Android/iOS/Chrome) |
| `image` | ^4.2.0 | Pré-processamento de OCR no desktop |
| `google_mlkit_text_recognition` | ^0.15.0 | OCR on-device em Android/iOS |

### 2.2 Arquivos novos (lib/)
```
lib/
├── core/
│   ├── api_config.dart                  ← URL backend por plataforma
│   ├── disorder_explanations.dart       ← Textos educativos por distúrbio
│   └── ingredient_dictionary.dart       ← ~190 termos + correção fuzzy
├── models/
│   └── enriched_analysis.dart           ← Resposta /analyze (com Nutri-Score, NOVA)
└── screens/
    └── barcode_screen.dart              ← Leitor + entrada manual
```

### 2.3 Refatorações principais

#### `services/ocr_service.dart`
- **Gate por plataforma**: `Platform.isAndroid || Platform.isIOS` → ML Kit; senão → Tesseract CLI.
- **Pipeline desktop** (Tesseract):
  - `bakeOrientation` (EXIF auto-rotate)
  - Upscale para 1800px, downscale para 3500px máx.
  - Grayscale + Gaussian blur leve + `normalize` (histograma) + unsharp mask
  - **2 variantes**: binarização normal e invertida (auto-detecta predomínio de luminância)
  - **2 PSMs** (6, 4) × 2 variantes = 4 chamadas em **paralelo** via `Future.wait`
  - **Score**: termos do dicionário (peso 100) + caracteres alfa (peso 1)
- **Pipeline mobile** (ML Kit): chamada direta `TextRecognizer.processImage`, sem preprocessing manual (o modelo já cuida).
- Retorno tipado: `OcrOutcome(text, qualityScore, isLowQuality)`.
- Threshold `_minQualityScore = 1` (relaxado de 2 para não bloquear fotos medianas).

#### `utils/text_parser.dart`
- Regex de prefixo case-insensitive (`INGREDIENTES`, `Composição`, `Contém`, ...).
- Regex de marcadores de fim (`PODE CONTER`, `INFORMAÇÃO NUTRICIONAL`, `VALIDADE`, ...).
- Splitter que **respeita parênteses** (não quebra `vitaminas (A, B, C)`).
- Normalização de acentos via NFD + tabela.
- **Word boundary matching** (acaba com falsos positivos `sal`↔`salsa`).
- Coleta **múltiplos motivos** por ingrediente.
- **Correção fuzzy** pós-OCR via dicionário + mapa de erros frequentes (~35 entradas).
- `extractTraceWarnings`: captura `CONTÉM TRAÇOS DE...` / `PODE CONTER...` como avisos separados.
- `analyzeTraces`: cruza traços com perfil do usuário.

#### `core/constants.dart`
- 12 distúrbios (era 8): incluiu APLV, Alergia a Ovo/Amendoim/Soja, Crohn, Colite, Refluxo.
- Triggers expandidos com aliases (whey, caseinato, lactalbumina, shoyu, etc.).

#### `core/ingredient_dictionary.dart` (novo)
- ~190 entradas canônicas em PT-BR.
- Mapa de 35 correções pontuais para erros frequentes do OCR.
- API: `bestMatch(palavra)` retorna canônico mais próximo via Levenshtein (distância ≤ 2 absoluto e ≤ 0.25 relativo).
- API: `scoreText(texto)` conta termos válidos para pontuar variantes de OCR.

#### `core/disorder_explanations.dart` (novo)
- Conteúdo educativo por distúrbio: ícone, motivo curto (sintomas), parágrafo com mecanismo biológico.
- 12 distúrbios + chave "Alérgeno personalizado".

#### `core/api_config.dart` (novo)
- URL do backend dinâmica:
  - Override por `--dart-define=BACKEND_URL=...`
  - Web/Desktop: `http://localhost:3000/api`
  - Android emulador: `http://10.0.2.2:3000/api`
- Para device físico, exige `--dart-define`.

### 2.4 Telas

| Tela | Estado |
|---|---|
| `home_screen.dart` | Botões: Escanear, Ler Código de Barras, Histórico. Card de perfil. |
| `scan_screen.dart` | Galeria/Câmera + campo opcional de barcode + status OCR. Bloqueia só quando ingredientes ficam vazios. |
| `barcode_screen.dart` (novo) | `mobile_scanner` em mobile; entrada manual + sugestões em desktop. |
| `result_screen.dart` | Banner severidade, baixa qualidade, card produto (Nutri-Score + NOVA), alérgenos oficiais, traços, "Por que tomar cuidado?", listas. |
| `history_screen.dart` | Lista cronológica do provider local. |
| `profile_screen.dart` | Nome + distúrbios (checkboxes) + alérgenos personalizados (chips). |

### 2.5 Removidos
- `camera_screen.dart` (placeholder não usado).
- Integração com Edamam (chaves placeholder que falhariam).

---

## <a name="android"></a>3. Android (build + runtime)

### 3.1 Toolchain
| Componente | Antes | Agora |
|---|---|---|
| Gradle | 7.5 | **8.11.1** |
| AGP (Android Gradle Plugin) | 7.3.0 | **8.9.1** |
| Kotlin | 1.7.10 | **2.1.0** |
| Java | 1.8 | **17** |
| `minSdkVersion` | 19 (default Flutter antigo) | **21** (requisito ML Kit + mobile_scanner) |
| `applicationId` | `com.example.mobile` | **`com.example.nutriscan`** |
| `android:label` | `mobile` | **`NutriScan`** |

### 3.2 `AndroidManifest.xml` — permissões adicionadas
- `INTERNET`, `ACCESS_NETWORK_STATE`
- `CAMERA`
- `READ_MEDIA_IMAGES` (Android 13+)
- `READ_EXTERNAL_STORAGE` com `maxSdkVersion=32`
- `<uses-feature android:name="android.hardware.camera" required="false"/>` (câmera opcional)
- `<queries>` para Android 11+ resolver intents de imagem
- `<application android:networkSecurityConfig="@xml/network_security_config">`

### 3.3 `network_security_config.xml` (novo)
- `cleartextTraffic="true"` em base-config — permite HTTP em LAN para dev.
- A remover quando backend for HTTPS em produção.

### 3.4 `proguard-rules.pro` (novo) + minificação
- Build de release: `minifyEnabled true`, `shrinkResources true`.
- Regras: mantém classes do Flutter + ML Kit, ignora warnings de scripts asiáticos do ML Kit que não usamos e de Play Core (deferred components).
- APK release final: **~61MB** (com ML Kit bundle).

---

## <a name="docs-infra"></a>4. Documentação e infra

- `.gitignore` ajustado (node_modules, .env, IDEs).
- `docs/CHANGES.md` (este arquivo).
- Documentação prévia preservada: `ARCHITECTURE.md`, `REQUIREMENTS.md`, `VISION.md`, `SCOPE.md`, `STACK.md`.

---

## <a name="testes"></a>5. Testes automatizados

### 5.1 Backend (12 testes, runner nativo `node --test`)
- **analyzer.test.js** (9):
  - flagged ingredient quando há trigger correspondente
  - sem falso positivo "salsa" vs "sal"
  - alérgeno personalizado é detectado
  - múltiplos distúrbios geram múltiplos motivos
  - prioriza ingredientes do OCR sobre lista da OFF
  - usa OFF como fallback quando OCR vazio
  - mapeia allergens_tags para distúrbios
  - severidade escalona corretamente
  - payload vazio não quebra
- **routes.test.js** (3):
  - POST sem ingredientes nem barcode → 400
  - POST com ingredientes válidos → 200 + análise
  - POST com `disorders` inválido → 400

### 5.2 Mobile (1 widget test smoke)
- `App smoke test - renders NutriScan home`.

---

## <a name="cicd"></a>6. CI/CD

`.github/workflows/`
- **mobile-ci.yml** — `flutter analyze --fatal-warnings` + `flutter test --coverage` + build Linux smoke.
- **backend-ci.yml** — matrix Node 20/22, `npm ci` + `npm test`.
- **release-android.yml** — em push de tag `v*`, builda APKs split-per-abi e anexa ao GitHub Release.

---

## <a name="arq"></a>7. Decisões arquiteturais

### 7.1 Offline-first
A análise é feita localmente no app (parser + dicionário). O backend é **enriquecimento opcional**: se estiver fora, o usuário ainda vê ingredientes marcados como problemáticos.

### 7.2 Fonte única de triggers
`backend/src/data/disorderTriggers.js` espelha `mobile/lib/core/constants.dart`. Combinar em um único arquivo no futuro (gerador ou sync manual versionado).

### 7.3 Gate de plataforma para OCR
- Mobile (Android/iOS) → Google ML Kit (gratuito, on-device, ~10× melhor que Tesseract para fotos reais).
- Desktop → Tesseract CLI (dev only).
Isso simplifica testes em desktop sem perder performance em produção.

### 7.4 Cache de produtos da OFF
1h TTL no backend evita martelar a OFF e melhora latência em re-scans. Volátil — perde-se em restart. Migrar para Redis se ficar relevante.

### 7.5 Severidade gradual
`safe` / `warning` / `danger` calculado em: `flagged_ingredients + official_allergens + trace_warnings`. UI usa cor para reforço imediato (verde / amarelo / vermelho).
