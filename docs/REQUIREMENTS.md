# Especificação de Requisitos de Software (ERS)

**Projeto:** NutriScan — Protótipo Assistivo com OCR e Análise Nutricional para Apoio a Pessoas com Distúrbios Digestivos
**Vínculo acadêmico:** Iniciação Tecnológica (PIBITI), PI07741-2024/2, Instituto de Informática — UFG
**Versão:** 1.0
**Status:** Em desenvolvimento (MVP)
**Padrão de referência:** IEEE 830 / ISO/IEC/IEEE 29148

---

## 1. Introdução

### 1.1 Propósito

Este documento especifica os requisitos de software do protótipo **NutriScan**, um aplicativo móvel assistivo voltado ao apoio de pessoas com distúrbios digestivos (intolerâncias alimentares, doença celíaca, síndrome do intestino irritável, entre outros). O documento descreve **o que o sistema deve fazer**, sem prescrever tecnologias específicas de implementação, servindo como referência para desenvolvimento, validação, testes e avaliação acadêmica.

O propósito do sistema é permitir que o usuário fotografe o rótulo de um produto alimentício e receba, de forma rápida e acessível, a identificação de ingredientes potencialmente prejudiciais ao seu quadro clínico, além de informações nutricionais associadas.

### 1.2 Escopo

O sistema, denominado **NutriScan**, contempla:

- Cadastro e manutenção de **perfil digestivo** do usuário (distúrbios e alergênicos personalizados).
- **Captura de imagem** de rótulos alimentares.
- **Reconhecimento óptico de caracteres (OCR)** sobre a imagem capturada.
- **Identificação de ingredientes** a partir do texto extraído.
- **Comparação dos ingredientes** com o perfil digestivo do usuário, gerando alertas.
- **Recuperação de informação nutricional** via base/serviço externo.
- **Armazenamento de histórico** das análises realizadas.
- **Visualização de resultados** em interface acessível (alto contraste, leitor de tela, tipografia escalável).

**Fora do escopo** (conforme [SCOPE.md](SCOPE.md)):

- Treinamento de modelos próprios de aprendizado de máquina.
- Reconhecimento perfeito de texto sob qualquer condição de iluminação/ângulo.
- Autenticação avançada com múltiplos fatores ou login social.
- Publicação em lojas de aplicativos (Play Store, App Store).
- Aconselhamento médico ou prescrição dietética automatizada.

### 1.3 Definições, Acrônimos e Abreviações

| Termo | Definição |
|---|---|
| **OCR** | *Optical Character Recognition* — reconhecimento óptico de caracteres. |
| **MVP** | *Minimum Viable Product* — produto mínimo viável. |
| **ERS / SRS** | Especificação de Requisitos de Software. |
| **RF** | Requisito Funcional. |
| **RNF** | Requisito Não-Funcional. |
| **RN** | Regra de Negócio. |
| **API** | *Application Programming Interface*. |
| **REST** | *Representational State Transfer*. |
| **LGPD** | Lei Geral de Proteção de Dados Pessoais (Lei 13.709/2018). |
| **GDPR** | *General Data Protection Regulation* (UE). |
| **WCAG** | *Web Content Accessibility Guidelines*. |
| **SII / IBS** | Síndrome do Intestino Irritável. |
| **Gatilho dietético** | Ingrediente que tende a desencadear sintomas em um determinado distúrbio. |
| **Perfil digestivo** | Conjunto de distúrbios e alergênicos personalizados associados a um usuário. |

### 1.4 Referências

- IEEE Std 830-1998 — *Recommended Practice for Software Requirements Specifications*.
- ISO/IEC/IEEE 29148:2018 — *Systems and software engineering — Life cycle processes — Requirements engineering*.
- WCAG 2.2 — *Web Content Accessibility Guidelines*.
- Lei nº 13.709/2018 (LGPD).
- Plano de Trabalho PI07741-2024/2 — IC/UFG.
- Revisão Sistemática da Literatura: *Tecnologias Digitais e Assistivas para Apoio a Pessoas com Distúrbios Digestivos*.
- Documentos internos: [SCOPE.md](SCOPE.md), [ARCHITECTURE.md](ARCHITECTURE.md), [STACK.md](STACK.md).

### 1.5 Visão Geral do Documento

A Seção 2 apresenta uma descrição geral do produto, suas funções principais, perfis de usuários, restrições e suposições. A Seção 3 detalha os requisitos específicos (funcionais, não-funcionais e regras de negócio). A Seção 4 contém os casos de uso. A Seção 5 define critérios de aceitação. A Seção 6 apresenta a matriz de rastreabilidade entre requisitos, casos de uso e testes.

---

## 2. Descrição Geral

### 2.1 Perspectiva do Produto

O NutriScan é um sistema **autocontido**, composto por um aplicativo móvel e um serviço de retaguarda (*backend*) que se comunica com serviços externos de informação nutricional. Não substitui sistemas de prontuário eletrônico, nem se integra com sistemas hospitalares. Sua perspectiva é a de uma **ferramenta de apoio à autogestão alimentar**, alinhada às tendências apontadas pela RSL conduzida no projeto, especialmente quanto ao predomínio de aplicativos móveis de rastreamento alimentar (Digesty, mySymptoms, Endive).

```
+-------------------+       +-------------------+       +----------------------+
|   App Móvel       | <---> |   Backend REST    | <---> |  Serviço externo de  |
| (captura + OCR    |       | (perfis, scans,   |       |  nutrição (ex.: Open |
|  + UI acessível)  |       |  regra de alerta) |       |  Food Facts, Edamam) |
+-------------------+       +-------------------+       +----------------------+
                                     |
                                     v
                            +-------------------+
                            |  Persistência     |
                            |  (NoSQL/MongoDB)  |
                            +-------------------+
```

### 2.2 Funções do Produto

Em alto nível, o sistema oferece:

- **F1** Gestão de perfil digestivo do usuário.
- **F2** Captura de imagem de rótulo.
- **F3** Extração textual via OCR.
- **F4** Análise de ingredientes contra o perfil do usuário.
- **F5** Recuperação e exibição de informação nutricional.
- **F6** Geração de alertas personalizados.
- **F7** Histórico de análises.
- **F8** Configurações de acessibilidade.

### 2.3 Características dos Usuários (*Stakeholders*)

| Perfil | Descrição | Necessidades-chave |
|---|---|---|
| **Usuário-paciente** | Pessoa com um ou mais distúrbios digestivos diagnosticados ou suspeitos. | Identificar rapidamente ingredientes-gatilho; leitura clara; baixa carga cognitiva. |
| **Cuidador / familiar** | Acompanha rotina alimentar do paciente (ex.: pais de criança celíaca). | Interface simples, alertas inequívocos, histórico consultável. |
| **Profissional de saúde (nutricionista)** | Usuário secundário, consultado eventualmente. | Acesso a histórico para discussão clínica; dados estruturados. |
| **Pesquisador / orientador** | Avalia o protótipo em contexto acadêmico. | Logs, métricas de uso, reprodutibilidade. |
| **Desenvolvedor** | Mantém e evolui o software. | Código modular, documentação, pipelines de CI/CD. |

A RSL evidencia que o engajamento de usuários finais (pacientes e cuidadores) na validação é critério de qualidade recorrente — esse princípio orienta a priorização de requisitos de usabilidade e acessibilidade.

### 2.4 Restrições Gerais

- **R1** O OCR deve operar majoritariamente *on-device*, para reduzir dependência de rede em supermercado.
- **R2** A análise de alertas é **informativa** — não constitui aconselhamento médico (deve ser sinalizado em UI).
- **R3** Dados pessoais (perfil, histórico) devem ser tratados conforme a LGPD: minimização, finalidade, transparência, direito de exclusão.
- **R4** A solução deve funcionar em dispositivos Android de gama média (mínimo Android 8.0, 2 GB de RAM).
- **R5** O backend deve expor uma API REST estável documentada em JSON.
- **R6** O custo de operação do MVP deve caber em planos gratuitos de provedores em nuvem (ex.: Heroku/Render *free tier*).

### 2.5 Suposições e Dependências

- **S1** O usuário tem um *smartphone* com câmera traseira de pelo menos 5 MP.
- **S2** O rótulo do produto está legível, em português ou inglês, com texto impresso (não manuscrito).
- **S3** Existe conectividade intermitente — funcionalidades essenciais (OCR + alerta de gatilho) devem funcionar *offline*.
- **D1** O serviço externo de nutrição (ex.: Open Food Facts) está disponível e mantém contrato de API estável.
- **D2** O motor de OCR (ex.: Tesseract via plugin Flutter, Google ML Kit) suporta idiomas pt-BR e en.

---

## 3. Requisitos Específicos

Cada requisito é numerado e contém: descrição, entrada, saída e prioridade (**Alta**, **Média**, **Baixa**).

### 3.1 Requisitos Funcionais (RF)

#### Perfil do Usuário

**RF01 — Cadastrar perfil digestivo**
*Descrição:* O sistema deve permitir ao usuário criar um perfil contendo nome, lista de distúrbios digestivos e lista de alergênicos personalizados.
*Entrada:* Nome (texto), distúrbios (seleção múltipla a partir de catálogo predefinido), alergênicos personalizados (lista de texto livre).
*Saída:* Perfil persistido e retornado com identificador único.
*Prioridade:* **Alta**.

**RF02 — Editar perfil digestivo**
*Descrição:* O sistema deve permitir atualizar qualquer campo do perfil já cadastrado.
*Entrada:* Identificador do perfil + campos modificados.
*Saída:* Perfil atualizado.
*Prioridade:* **Alta**.

**RF03 — Excluir perfil digestivo**
*Descrição:* O sistema deve permitir excluir o perfil e, opcionalmente, o histórico associado, em conformidade com o direito de eliminação previsto na LGPD (Art. 18, VI).
*Entrada:* Identificador do perfil + confirmação.
*Saída:* Confirmação de exclusão.
*Prioridade:* **Média**.

**RF04 — Catálogo de distúrbios pré-cadastrados**
*Descrição:* O sistema deve oferecer um catálogo mínimo contendo: doença celíaca, intolerância à lactose, intolerância à frutose, SII/IBS, alergia a proteína do leite, alergia a ovo, alergia a amendoim, alergia a soja, doença de Crohn, refluxo gastroesofágico.
*Entrada:* —
*Saída:* Lista de distúrbios disponíveis para seleção.
*Prioridade:* **Alta**.

#### Captura e OCR

**RF05 — Capturar imagem de rótulo**
*Descrição:* O sistema deve permitir capturar uma fotografia do rótulo usando a câmera do dispositivo, com pré-visualização e opção de refazer.
*Entrada:* Ação de captura do usuário.
*Saída:* Imagem em memória, em formato adequado para OCR (mínimo 1280×720, JPEG/PNG).
*Prioridade:* **Alta**.

**RF06 — Selecionar imagem da galeria**
*Descrição:* O sistema deve permitir, alternativamente, escolher uma imagem já existente no dispositivo.
*Entrada:* Imagem selecionada.
*Saída:* Imagem carregada no fluxo de análise.
*Prioridade:* **Média**.

**RF07 — Extrair texto via OCR**
*Descrição:* O sistema deve processar a imagem e extrair o texto presente no rótulo.
*Entrada:* Imagem do rótulo.
*Saída:* Texto bruto reconhecido (`raw_text`).
*Prioridade:* **Alta**.

**RF08 — Pré-processar imagem antes do OCR**
*Descrição:* O sistema deve aplicar técnicas de pré-processamento (correção de perspectiva, binarização, ajuste de contraste) para melhorar a acurácia, conforme evidenciado pela literatura (Bugayong et al., 2022; Charjan et al., 2013).
*Entrada:* Imagem bruta.
*Saída:* Imagem pré-processada.
*Prioridade:* **Média**.

#### Análise de Ingredientes

**RF09 — Identificar lista de ingredientes**
*Descrição:* A partir do texto bruto, o sistema deve extrair a lista de ingredientes do produto.
*Entrada:* `raw_text`.
*Saída:* Lista estruturada de ingredientes (`[{name}]`).
*Prioridade:* **Alta**.

**RF10 — Comparar ingredientes com perfil digestivo**
*Descrição:* Cada ingrediente identificado deve ser comparado com os distúrbios e alergênicos do usuário, marcando os que representam risco.
*Entrada:* Lista de ingredientes + perfil do usuário.
*Saída:* Lista de ingredientes com `is_flagged`, `flag_reason`, `related_disorder`.
*Prioridade:* **Alta**.

**RF11 — Exibir alertas destacados**
*Descrição:* O sistema deve apresentar os ingredientes sinalizados em destaque visual e textual (cor, ícone e descrição), de forma que o alerta seja perceptível sem depender apenas de cor (WCAG 1.4.1).
*Entrada:* Resultado da análise.
*Saída:* Tela de resultado com alertas.
*Prioridade:* **Alta**.

#### Nutrição

**RF12 — Recuperar informação nutricional**
*Descrição:* O sistema deve, quando possível, recuperar informações nutricionais (calorias, carboidratos, açúcares, fibras, proteínas, gorduras totais e saturadas, sódio) do produto identificado ou do texto extraído.
*Entrada:* Texto do rótulo ou identificador do produto.
*Saída:* Objeto `nutrition_info`.
*Prioridade:* **Média**.

**RF13 — Exibir informação nutricional**
*Descrição:* O sistema deve apresentar a tabela nutricional de forma legível, com tipografia escalável.
*Entrada:* `nutrition_info`.
*Saída:* Tabela renderizada.
*Prioridade:* **Média**.

#### Histórico

**RF14 — Persistir resultado de análise**
*Descrição:* Cada análise deve ser persistida com texto extraído, ingredientes, alertas, informação nutricional e timestamp.
*Entrada:* Resultado completo.
*Saída:* Registro salvo com identificador.
*Prioridade:* **Alta**.

**RF15 — Listar histórico de análises**
*Descrição:* O usuário deve poder consultar suas análises anteriores, ordenadas por data decrescente.
*Entrada:* —
*Saída:* Lista paginada de análises.
*Prioridade:* **Alta**.

**RF16 — Detalhar análise do histórico**
*Descrição:* O usuário deve poder reabrir uma análise anterior e ver seu detalhe.
*Entrada:* Identificador da análise.
*Saída:* Tela de resultado preenchida.
*Prioridade:* **Média**.

**RF17 — Excluir análise do histórico**
*Descrição:* O usuário deve poder excluir um item do histórico individualmente.
*Entrada:* Identificador da análise + confirmação.
*Saída:* Confirmação de exclusão.
*Prioridade:* **Média**.

#### Acessibilidade e Configuração

**RF18 — Ajustar tamanho de fonte**
*Descrição:* O sistema deve respeitar o ajuste de fonte do sistema operacional e oferecer opção interna de aumento adicional.
*Entrada:* Configuração do usuário.
*Saída:* UI re-renderizada.
*Prioridade:* **Alta**.

**RF19 — Suporte a leitor de tela**
*Descrição:* Todos os elementos interativos e informativos devem ter rótulos semânticos compatíveis com TalkBack (Android) e VoiceOver (iOS).
*Entrada:* Foco do leitor de tela.
*Saída:* Anúncio textual coerente.
*Prioridade:* **Alta**.

**RF20 — Modo alto contraste**
*Descrição:* O sistema deve oferecer um tema de alto contraste para usuários com baixa visão.
*Entrada:* Configuração do usuário.
*Saída:* UI com paleta alternativa.
*Prioridade:* **Média**.

**RF21 — Feedback sonoro/tátil em alertas críticos**
*Descrição:* O sistema deve emitir vibração e/ou som ao identificar ingredientes sinalizados como gatilhos.
*Entrada:* Resultado com `flagged_ingredients` não vazio.
*Saída:* Sinal háptico/sonoro.
*Prioridade:* **Baixa**.

### 3.2 Requisitos Não-Funcionais (RNF)

#### Desempenho

**RNF01 — Tempo de OCR** O processamento de OCR sobre uma imagem de até 1080p deve ser concluído em **no máximo 5 segundos** em um dispositivo Android de gama média (referência: Snapdragon 6xx, 4 GB RAM).
**RNF02 — Latência de API** O tempo de resposta da chamada `POST /api/scans` deve ser inferior a **2 segundos** no percentil 95, excluído o tempo de OCR.
**RNF03 — Tamanho do app** O APK do MVP deve ter no máximo **80 MB**.

#### Usabilidade

**RNF04 — Curva de aprendizado** Um usuário leigo deve concluir o fluxo *capturar → ver resultado* em até **3 toques** após abrir o app, sem treinamento prévio.
**RNF05 — Linguagem clara** Mensagens devem ser escritas em português coloquial, evitando termos médicos sem glossário (princípio de *plain language*).
**RNF06 — Recuperação de erro** Em caso de falha de OCR ou rede, o sistema deve oferecer ação corretiva clara (refazer foto, tentar novamente, usar modo offline).

#### Acessibilidade

**RNF07 — Conformidade WCAG** A interface deve atender, no mínimo, ao nível **AA do WCAG 2.2** para *mobile*: contraste mínimo 4,5:1 para texto comum, área mínima de toque de 44×44 dp, foco visível.
**RNF08 — Independência de cor** Nenhuma informação deve ser transmitida apenas por cor (uso combinado de ícone + texto + cor).
**RNF09 — Internacionalização** A interface deve suportar pt-BR como idioma primário e estar preparada para localização (`intl`).

#### Segurança e Privacidade (LGPD)

**RNF10 — Minimização de dados** O sistema deve coletar apenas dados estritamente necessários ao seu funcionamento — não solicita CPF, e-mail, telefone ou geolocalização no MVP.
**RNF11 — Consentimento** Na primeira execução, o sistema deve apresentar um aviso de privacidade explicando os dados tratados, com aceite explícito antes do uso.
**RNF12 — Transporte seguro** Toda a comunicação entre app e backend deve usar HTTPS/TLS 1.2+.
**RNF13 — Armazenamento local** Perfil e histórico armazenados localmente devem residir em área privada do app (não acessível por outros aplicativos).
**RNF14 — Direito de eliminação** O usuário deve poder, em uma única ação, apagar todo o seu perfil e histórico (Art. 18 LGPD).
**RNF15 — Anonimato no backend** O backend não deve armazenar identificadores diretos (nome real) sem necessidade — preferir identificadores opacos por dispositivo.

#### Disponibilidade e Confiabilidade

**RNF16 — Operação offline** OCR e comparação com perfil devem funcionar sem conexão à internet.
**RNF17 — Disponibilidade do backend** O serviço deve manter disponibilidade mensal ≥ **95%** durante o período da IC (compatível com *free tier* de PaaS).
**RNF18 — Tolerância a falha de serviço externo** Se a API de nutrição estiver indisponível, o sistema deve seguir exibindo ingredientes e alertas (degradação graciosa).

#### Portabilidade

**RNF19 — Plataforma móvel** O aplicativo deve ser executável em Android (versão prioritária do MVP) e, futuramente, iOS, a partir de uma base de código única.
**RNF20 — Plataforma de backend** O backend deve poder ser executado em ambiente Linux com Node.js LTS e MongoDB compatível (versão 6+ ou Atlas).

#### Manutenibilidade

**RNF21 — Modularidade** O código deve separar claramente camadas de UI, serviços, modelos e infraestrutura.
**RNF22 — Cobertura mínima de testes** O backend deve ter cobertura de testes unitários ≥ **60%** nas rotas críticas (perfis, scans, regra de alerta).
**RNF23 — Pipelines de CI/CD** Cada *push* na *branch* principal deve disparar lint, testes automatizados e *build* via GitHub Actions.

#### Ética

**RNF24 — Não-substituição de aconselhamento médico** Toda tela de resultado deve exibir, de forma visível, *disclaimer* indicando que o conteúdo é informativo e não substitui orientação profissional.
**RNF25 — Viés do OCR** Resultados com confiança baixa devem ser sinalizados ao usuário como "possível leitura imprecisa", evitando falsos negativos silenciosos.

### 3.3 Regras de Negócio (RN)

**RN01 — Marcação de ingrediente como gatilho**
Um ingrediente é marcado como `is_flagged = true` quando seu nome (normalizado: *lowercase*, sem acentos, sem pontuação) contém **qualquer substring** da união entre:
- a lista de gatilhos associados aos distúrbios selecionados pelo usuário; e
- a lista de `custom_allergens` do perfil.

A `flag_reason` registra o termo casado e o `related_disorder` registra qual distúrbio (ou "personalizado") originou a regra.

**RN02 — Tabela canônica de gatilhos por distúrbio**

| Distúrbio | Gatilhos (substrings de busca) |
|---|---|
| Doença celíaca | trigo, glúten, cevada, centeio, malte, aveia, triticale, farinha de trigo |
| Intolerância à lactose | leite, lactose, soro de leite, manteiga, queijo, creme de leite |
| Intolerância à frutose | frutose, xarope de milho, mel, xarope de frutose, sorbitol |
| Alergia a proteína do leite | leite, caseína, soro de leite, lactalbumina |
| Alergia a ovo | ovo, albumina, lecitina de ovo |
| Alergia a amendoim | amendoim, *peanut* |
| Alergia a soja | soja, lecitina de soja, proteína de soja |
| SII/IBS (alto FODMAP) | cebola, alho, trigo, mel, sorbitol, manitol, xilitol, frutose |
| Refluxo gastroesofágico | cafeína, chocolate, hortelã, pimenta |
| Doença de Crohn (genérico) | lactose, glúten, álcool, cafeína |

> A tabela é configurável e versionada no backend. Mudanças devem ser rastreáveis via *changelog*.

**RN03 — Resultado sem ingredientes sinalizados**
Quando `flagged_ingredients` está vazio, o sistema apresenta o estado "Sem alertas para o seu perfil", **sem afirmar que o produto é seguro** — apenas que não há correspondência na base de gatilhos atual.

**RN04 — Sem perfil ativo**
Se não existir perfil cadastrado, o sistema deve apresentar a análise apenas com o texto bruto e a lista de ingredientes, sem geração de alertas, e convidar o usuário a cadastrar um perfil.

**RN05 — Histórico vinculado ao dispositivo**
Histórico e perfil pertencem ao dispositivo (ou conta, em fase futura). Trocas de dispositivo não migram dados no MVP.

**RN06 — Tempo de retenção**
Análises são mantidas indefinidamente até que o usuário as exclua. Em caso de desinstalação, dados locais são removidos pelo sistema operacional.

**RN07 — Análise sem reconhecimento**
Se o OCR retornar texto vazio ou ilegível (heurística: menos de 10 caracteres reconhecidos), o sistema **não** persiste o resultado e solicita nova captura.

---

## 4. Casos de Uso

### UC01 — Cadastrar perfil digestivo

- **Ator:** Usuário-paciente.
- **Pré-condição:** Aplicativo instalado.
- **Fluxo principal:**
  1. Usuário acessa a tela "Perfil".
  2. Informa nome.
  3. Seleciona um ou mais distúrbios do catálogo (RF04).
  4. Adiciona, opcionalmente, alergênicos personalizados.
  5. Confirma.
- **Pós-condição:** Perfil persistido localmente e replicado no backend.
- **Fluxos alternativos:**
  - 5a. Falha de rede: perfil salvo apenas localmente e marcado como pendente de sincronização.

### UC02 — Escanear rótulo de produto

- **Ator:** Usuário-paciente.
- **Pré-condição:** Perfil cadastrado (UC01).
- **Fluxo principal:**
  1. Usuário aciona "Escanear".
  2. Sistema abre a câmera.
  3. Usuário enquadra o rótulo e captura (RF05).
  4. Sistema pré-processa a imagem (RF08).
  5. Sistema aplica OCR (RF07).
  6. Sistema identifica ingredientes (RF09).
  7. Sistema aplica RN01 sobre o perfil ativo.
  8. Sistema (se houver conectividade) chama serviço de nutrição (RF12).
  9. Sistema apresenta resultado (RF11, RF13).
- **Pós-condição:** Resultado persistido no histórico (RF14).
- **Fluxos alternativos:**
  - 5a. OCR retorna texto insuficiente → aplica RN07 e solicita nova captura.
  - 8a. Serviço de nutrição indisponível → resultado é exibido sem tabela nutricional (RNF18).

### UC03 — Consultar histórico

- **Ator:** Usuário-paciente.
- **Pré-condição:** Existe ao menos uma análise persistida.
- **Fluxo principal:**
  1. Usuário acessa "Histórico" (RF15).
  2. Sistema lista análises por data decrescente.
  3. Usuário seleciona uma análise (RF16).
  4. Sistema exibe detalhe equivalente ao da tela de resultado.

### UC04 — Excluir dados pessoais

- **Ator:** Usuário-paciente.
- **Pré-condição:** Perfil e/ou histórico existentes.
- **Fluxo principal:**
  1. Usuário acessa "Configurações" → "Privacidade".
  2. Solicita "Apagar meus dados".
  3. Sistema solicita confirmação.
  4. Sistema remove perfil (RF03) e histórico (RF17) localmente e remotamente.
- **Pós-condição:** Conformidade com Art. 18 da LGPD (direito à eliminação).

### UC05 — Usar o app com leitor de tela

- **Ator:** Usuário-paciente com deficiência visual.
- **Pré-condição:** TalkBack/VoiceOver ativo.
- **Fluxo principal:**
  1. Usuário navega entre elementos com gestos do leitor.
  2. Cada elemento anuncia rótulo coerente (RF19).
  3. Ao chegar à tela de resultado, ingredientes sinalizados são anunciados primeiro, com prefixo "Alerta:" (RF11, RNF08).

---

## 5. Critérios de Aceitação

Para cada requisito-chave, define-se critério verificável.

| ID | Requisito | Critério de aceitação |
|---|---|---|
| CA01 | RF01 | Dado um usuário sem perfil, ao preencher nome e selecionar pelo menos um distúrbio, o perfil é persistido e retornado por `GET /api/profiles/:id` em até 1 s. |
| CA02 | RF05 + RF07 | Em 10 imagens-teste de rótulos reais (controle + condição variada), o OCR retorna texto não vazio em ≥ 9 casos. |
| CA03 | RF10 + RN01 | Em um conjunto de 20 rótulos rotulados manualmente como contendo gatilho do perfil, o sistema sinaliza corretamente em ≥ 17 casos (recall ≥ 85%). |
| CA04 | RF11 + RNF07 | Auditoria de contraste com ferramenta automatizada (ex.: *axe*, *Accessibility Scanner*) não retorna violação de contraste em nenhuma tela. |
| CA05 | RF14 + RF15 | Após análise, o item aparece em primeiro lugar em `GET /api/scans`, ordenado por `scanned_at` decrescente. |
| CA06 | RF19 | Em teste com TalkBack, 100% dos elementos interativos da tela de resultado são anunciados com rótulo significativo. |
| CA07 | RNF01 | Em 20 medições no dispositivo de referência, a mediana do tempo de OCR é ≤ 5 s. |
| CA08 | RNF11 + RNF14 | No primeiro uso, o aviso de privacidade é exibido. A opção "Apagar meus dados" remove perfil e histórico verificáveis por `GET` retornando 404. |
| CA09 | RNF18 | Simulando indisponibilidade da API de nutrição (mock de erro 503), o app exibe a análise com ingredientes e alertas, sem travar. |
| CA10 | RN07 | Imagem de teste em branco/borrada produz mensagem de "leitura inválida" e **não** gera registro em `/api/scans`. |

---

## 6. Matriz de Rastreabilidade

Liga **Requisito ↔ Caso de Uso ↔ Critério de Aceitação ↔ Componente / Teste**.

| Requisito | Caso de Uso | Critério | Componente principal | Teste |
|---|---|---|---|---|
| RF01 | UC01 | CA01 | `backend/routes/profiles.js`, `mobile/screens/profile_screen.dart` | unitário backend + widget test |
| RF02 | UC01 | — | `profiles.js` (PUT), `profile_screen.dart` | unitário backend |
| RF03 | UC04 | CA08 | `profiles.js` (DELETE) | unitário backend |
| RF04 | UC01 | — | catálogo embutido no app | inspeção |
| RF05 | UC02 | CA02 | `mobile/screens/camera_screen.dart` | manual |
| RF06 | UC02 | — | `camera_screen.dart` | manual |
| RF07 | UC02 | CA02, CA07 | `mobile/services/ocr_service.dart` | unitário + benchmark |
| RF08 | UC02 | — | `ocr_service.dart` | unitário |
| RF09 | UC02 | — | `mobile/utils/text_parser.dart` | unitário |
| RF10 | UC02 | CA03 | regra no backend (`scans.js`) ou `app_provider.dart` | unitário (suite de gatilhos) |
| RF11 | UC02, UC05 | CA04, CA06 | `mobile/screens/result_screen.dart` | acessibilidade |
| RF12 | UC02 | CA09 | `mobile/services/nutrition_service.dart` | integração com mock |
| RF13 | UC02 | — | `result_screen.dart` | widget test |
| RF14 | UC02 | CA05 | `scans.js` (POST), `ScanResult.js` | unitário backend |
| RF15 | UC03 | CA05 | `scans.js` (GET), `mobile/screens/history_screen.dart` | unitário + widget test |
| RF16 | UC03 | — | `scans.js` (GET/:id) | unitário backend |
| RF17 | UC04 | CA08 | `scans.js` (DELETE) | unitário backend |
| RF18–RF21 | UC05 | CA04, CA06 | `mobile/core/theme.dart` | acessibilidade |
| RN01 | UC02 | CA03 | regra de marcação (backend) | suite de testes com pares (perfil, rótulo) |
| RN07 | UC02 | CA10 | OCR + validação no backend | unitário |
| RNF01 | UC02 | CA07 | `ocr_service.dart` | benchmark |
| RNF07–RNF09 | UC05 | CA04, CA06 | tema + componentes | varredura automatizada |
| RNF11, RNF14 | UC04 | CA08 | tela de privacidade + DELETE | manual + unitário |

---

## 7. Anexos

### 7.1 Modelo de Dados Resumido

```jsonc
// UserProfile
{
  "_id": "ObjectId",
  "name": "string",
  "disorders": ["celiac", "lactose_intolerance", ...],
  "custom_allergens": ["amendoim", ...],
  "createdAt": "ISODate",
  "updatedAt": "ISODate"
}

// ScanResult
{
  "_id": "ObjectId",
  "raw_text": "string",
  "ingredients": [
    {
      "name": "string",
      "is_flagged": false,
      "flag_reason": null,
      "related_disorder": null
    }
  ],
  "nutrition_info": {
    "calories": 0, "total_fat": 0, "saturated_fat": 0,
    "carbohydrates": 0, "sugars": 0, "fiber": 0,
    "protein": 0, "sodium": 0
  },
  "flagged_ingredients": [/* mesmo schema de ingredients */],
  "image_path": "string|null",
  "scanned_at": "ISODate"
}
```

### 7.2 Endpoints REST (resumo)

| Método | Rota | Função | Requisito |
|---|---|---|---|
| GET | `/api/health` | *Health check* | — |
| GET | `/api/profiles` | Lista perfis | RF01 |
| POST | `/api/profiles` | Cria perfil | RF01 |
| GET | `/api/profiles/:id` | Detalha perfil | RF01 |
| PUT | `/api/profiles/:id` | Atualiza perfil | RF02 |
| DELETE | `/api/profiles/:id` | Remove perfil | RF03, RNF14 |
| GET | `/api/scans` | Lista análises | RF15 |
| POST | `/api/scans` | Persiste análise | RF14 |
| GET | `/api/scans/:id` | Detalha análise | RF16 |
| DELETE | `/api/scans/:id` | Remove análise | RF17, RNF14 |

### 7.3 Glossário de Distúrbios e Termos Clínicos

Para uso em UI e em catálogo (RF04), com descrições curtas e acessíveis:

- **Doença celíaca:** doença autoimune desencadeada pela ingestão de glúten.
- **Intolerância à lactose:** dificuldade em digerir o açúcar do leite.
- **SII/IBS:** distúrbio funcional intestinal sensível a alimentos do tipo FODMAP.
- **Alergia alimentar:** resposta imune adversa a uma proteína específica.

---

## 8. Controle de Versão do Documento

| Versão | Data | Autor | Mudanças |
|---|---|---|---|
| 1.0 | 2026-05-12 | José Fernandes (orientação: Profa. Elisangela Dias; co-orientação: Maurício Lima) | Versão inicial alinhada ao MVP e à RSL. |
