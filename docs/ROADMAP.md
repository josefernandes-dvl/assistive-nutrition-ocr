# NutriScan — Roadmap de Melhorias Futuras

Lista priorizada por impacto/esforço. Marcadores: 🔥 alto impacto, 🛠 esforço.

---

## 🔥 Tier 1 — Bloqueadores para um piloto real

### 1.1 Persistência local de perfil e histórico  🔥🔥🔥 · 🛠
**Hoje**: tudo só em memória. Reinstalar/fechar = perde tudo.
**Fazer**: usar `shared_preferences` (perfil) e `hive` ou `sqlite` (histórico). Sincronizar com backend quando online.
**Por quê**: sem isso, ninguém vai usar de verdade — toda análise é descartada.

### 1.2 Cropper de imagem antes do OCR  🔥🔥 · 🛠🛠
**Hoje**: o OCR processa a foto inteira; muita foto inclui ¾ de embalagem irrelevante, prejudicando precisão.
**Fazer**: pacote `crop_your_image` (web/desktop/mobile) ou `image_cropper` (mobile). UI: após selecionar foto, mostra editor para o usuário arrastar um retângulo só sobre os ingredientes.
**Ganho esperado**: precisão do OCR salta drasticamente em fotos reais.

### 1.3 Deploy do backend (Render / Fly.io)  🔥🔥 · 🛠
**Hoje**: backend só roda na máquina dev; testadores precisam estar na mesma LAN.
**Fazer**: Dockerfile + workflow GitHub Actions de deploy. Render tem free tier suficiente para piloto. Configurar `BACKEND_URL` para a URL HTTPS no build.
**Por quê**: requisito para qualquer sessão de usabilidade com usuários reais.

### 1.4 Pop-up de permissões guiado  🔥 · 🛠
**Hoje**: se o usuário negar câmera/galeria, o app trava silenciosamente.
**Fazer**: pacote `permission_handler`, com diálogos explicando por que cada permissão é pedida + botão "abrir configurações" se negada permanentemente.

---

## 🔥 Tier 2 — Refinamento da experiência

### 2.1 Validação clínica dos triggers e textos  🔥🔥 · 🛠
**Hoje**: lista de triggers e [explicações](mobile/lib/core/disorder_explanations.dart) foram compiladas de literatura geral.
**Fazer**: revisão por nutricionista/gastroenterologista. Documentar fontes. Adicionar disclaimer "informativo, não substitui orientação médica".

### 2.2 Tela de "diagnóstico do produto" pós-OCR  🔥 · 🛠
**Hoje**: o usuário vê a lista bruta + alertas. Não há um veredito visual rápido tipo semáforo.
**Fazer**: hero card no topo do ResultScreen com avatar do produto + 1 frase em destaque ("Você **pode** consumir" / "Você **não deve** consumir" / "Atenção: risco de contaminação cruzada").

### 2.3 Histórico com filtros e busca  🔥 · 🛠
**Hoje**: lista cronológica simples.
**Fazer**: filtro por severidade, busca por nome de produto/ingrediente, agrupamento por mês.

### 2.4 Compartilhar análise  🔥 · 🛠
**Hoje**: nenhum jeito de levar a análise para fora.
**Fazer**: botão "Compartilhar" no ResultScreen → gera imagem ou texto pré-formatado para WhatsApp/email/nutricionista.

### 2.5 Suporte a múltiplos perfis  🔥 · 🛠🛠
**Hoje**: 1 perfil por instalação.
**Fazer**: lista de perfis (esposa, filho, pai...) com switch rápido. Útil para famílias com diferentes restrições.

---

## 🛠 Tier 3 — Plataforma & alcance

### 3.1 iOS  🔥 · 🛠🛠
**Hoje**: nunca buildado para iOS.
**Fazer**: ML Kit, mobile_scanner e image_picker já suportam iOS. Falta `Info.plist` com `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`. Buildar com `flutter build ios` — exige Mac.

### 3.2 Suporte a múltiplos idiomas (i18n)  🔥 · 🛠🛠
**Hoje**: textos hardcoded em PT-BR.
**Fazer**: `flutter_localizations` + `intl`. Inglês e espanhol já cobrem mercado regional. Triggers precisam de variantes por idioma.

### 3.3 Vision LLM como engine premium  🔥🔥 · 🛠🛠
**Hoje**: ML Kit é bom, mas ainda erra rótulos curvos/refletivos.
**Fazer**: integração com Claude Vision / Gemini Vision como **opção opcional do usuário** (chave de API própria). Custa por imagem (~R$ 0,02 por foto), mas qualidade próxima de 100%.
**Trade-off**: requer conexão e chave. Bom para usuários power.

---

## 🎨 Tier 4 — Acessibilidade & polimento

### 4.1 Acessibilidade real  🔥🔥 · 🛠🛠
- **Leitor de tela** (TalkBack/VoiceOver): adicionar `Semantics` widgets em todos os botões e cards. Hoje só funcionalmente acessível.
- **Modo alto contraste**: já é RNF do projeto. Tema separado com cores AA/AAA.
- **Escala de fonte**: respeitar `MediaQuery.textScaler` para acomodar usuários idosos.
- **Tap target**: garantir 48dp mínimo (Botões já OK; chips e ícones na lista de ingredientes precisam revisão).

### 4.2 Ícone de app e branding  🛠
**Hoje**: ícone padrão do Flutter.
**Fazer**: design de ícone (estilo flat, cores do tema). `flutter_launcher_icons` para gerar em todas as resoluções.

### 4.3 Splash screen customizada  🛠
**Hoje**: tela branca no boot.
**Fazer**: `flutter_native_splash` com logo NutriScan + cor verde.

### 4.4 Animações suaves  🛠
- Transição banner severidade (escala em entrada).
- Loader durante OCR com indicador de progresso por etapa ("Pré-processando → OCR → Análise → Enriquecimento").

---

## 🔬 Tier 5 — Pesquisa & qualidade

### 5.1 Dataset de validação automatizada  🔥 · 🛠🛠
**Hoje**: testamos OCR manualmente foto a foto.
**Fazer**: pasta `test/fixtures/` com 30+ fotos reais de rótulos + ground truth (ingredientes esperados). Teste Dart que roda OCR + parser e mede recall/precision. Permite quantificar cada mudança no pipeline.

### 5.2 Telemetria opt-in  🔥 · 🛠🛠
**Hoje**: sem instrumentação.
**Fazer**: tempo de cada etapa do scan, taxa de "qualidade baixa", taxa de produtos encontrados na OFF, distribuição de distúrbios mais comuns. Útil para o relatório do IC. Pode ser local-only (sem servidor) com export JSON.

### 5.3 Métricas SUS contínuas  🔥 · 🛠
**Hoje**: SUS planejada como sessão pontual.
**Fazer**: pop-up opcional "Avalie sua experiência (1-5)" depois de N análises. Coletar para o relatório.

### 5.4 Testes E2E com `integration_test`  🛠🛠
**Hoje**: 1 widget test smoke.
**Fazer**: fluxo completo home → perfil → scan → resultado, rodando no CI em emulador Android.

---

## 🛡 Tier 6 — Robustez técnica

### 6.1 Autenticação no backend  🛠🛠
**Hoje**: API totalmente aberta.
**Fazer**: JWT simples + endpoint `/auth/anonymous` (cria token persistente). Não precisa cadastro — só identifica devices.

### 6.2 Rate limiting  🛠
**Hoje**: API exposta ao mundo.
**Fazer**: `express-rate-limit` por IP. Importante após deploy público.

### 6.3 Validação rigorosa com schema  🛠
**Hoje**: rotas fazem checagem manual de tipos.
**Fazer**: `zod` ou `joi` — payload mal formado vira 400 estruturado.

### 6.4 Cache OFF persistente (Redis)  🛠🛠
**Hoje**: cache em memória, perde em restart.
**Fazer**: Redis ou cache em arquivo JSON. Para o IC, JSON em disco resolve sem custo extra.

### 6.5 Backup automático do MongoDB  🛠
**Hoje**: dado vira pó se Mongo crashar.
**Fazer**: cron diário dumpando para S3 / Backblaze (free tier).

---

## Prioridades sugeridas para os próximos 30 dias

| # | Item | Justificativa |
|---|---|---|
| 1 | **Persistência local** (1.1) | Hoje o app é "demonstrável" mas não "usável". |
| 2 | **Deploy do backend** (1.3) | Necessário para qualquer teste fora da LAN. |
| 3 | **Validação clínica** (2.1) | Crítico antes de qualquer apresentação acadêmica. |
| 4 | **Cropper de imagem** (1.2) | Maior ganho de qualidade em fotos reais. |
| 5 | **Sessão de usabilidade com 5 usuários** (testing plan já documentado) | Insights que mudam o produto. |
| 6 | **Telemetria opt-in** (5.2) | Dá números para o relatório do IC. |

Resto pode esperar a próxima iteração ou ficar como backlog público.
