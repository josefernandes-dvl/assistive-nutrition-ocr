# Visão do Projeto

## 1. Contexto

Distúrbios digestivos — como intolerâncias alimentares (lactose, glúten),
doença celíaca, síndrome do intestino irritável (SII) e alergias alimentares —
afetam uma parcela significativa da população e exigem controle alimentar
rigoroso, contínuo e individualizado. A leitura de rótulos nutricionais,
atividade cotidiana central para essas pessoas, é dificultada por:

- Tipografia reduzida e baixo contraste nas embalagens;
- Nomes técnicos e sinônimos comerciais que ocultam ingredientes-gatilho;
- Tempo limitado de decisão em supermercados ou refeições fora de casa;
- Barreiras adicionais para pessoas com deficiência visual ou baixa
  letramento em informação nutricional.

A Revisão Sistemática da Literatura conduzida no âmbito desta pesquisa
evidenciou que, embora aplicativos móveis de rastreamento alimentar
(Endive, mySymptoms, Digesty, entre outros) sejam a categoria mais
explorada, persistem lacunas relevantes na literatura: poucas soluções
combinam **OCR + análise nutricional automatizada + perfil de restrições
do usuário**; aspectos de **acessibilidade**, **usabilidade** e
**conformidade ética/legal (LGPD/GDPR/HIPAA)** raramente são tratados
de forma integrada; e a personalização para distúrbios específicos
(SII, doença celíaca, intolerâncias) ainda é incipiente.

## 2. Visão

> Oferecer um protótipo móvel assistivo que permita a pessoas com
> distúrbios digestivos verificar, de forma rápida, acessível e
> confiável, se um produto alimentício é seguro para o seu perfil,
> apoiando decisões alimentares cotidianas e reduzindo o esforço
> cognitivo da leitura de rótulos.

O projeto se posiciona como **prova de conceito acadêmica** (MVP de
Iniciação Tecnológica), com foco em validar a viabilidade técnica
da cadeia *captura → OCR → identificação de ingredientes → alerta
personalizado* e a usabilidade dessa cadeia junto a usuários reais.

## 3. Público-Alvo

**Usuários primários:**
- Pessoas com intolerâncias alimentares (lactose, glúten, frutose);
- Pessoas com doença celíaca;
- Pessoas com SII e dietas restritivas (ex.: low-FODMAP);
- Pessoas com alergias alimentares declaradas.

**Usuários secundários:**
- Cuidadores e familiares que auxiliam no controle alimentar;
- Nutricionistas, como apoio à orientação de pacientes;
- Pesquisadores interessados em prototipagem assistiva.

## 4. Proposta de Valor

| Dor do usuário | Resposta do protótipo |
|---|---|
| Rótulos com letras pequenas e termos técnicos | Captura por câmera + OCR (Tesseract pt-BR/en) |
| Dificuldade em saber se um ingrediente é seguro | Cruzamento com perfil de restrições do usuário |
| Falta de tempo para análise no ponto de compra | Alerta visual imediato (seguro / atenção / evitar) |
| Soluções pouco acessíveis | UI com fontes escaláveis, contraste alto, compatibilidade com leitor de tela |
| Insegurança quanto ao uso de dados pessoais | Armazenamento mínimo e princípios da LGPD |

## 5. Objetivos

### 5.1. Objetivo Geral

Desenvolver e disponibilizar um protótipo funcional de aplicativo
assistivo para apoio à gestão alimentar de pessoas com distúrbios
digestivos, integrando OCR, base de dados nutricional e perfil de
restrições do usuário.

### 5.2. Objetivos Específicos

1. Definir arquitetura de software (mobile + backend + persistência)
   e infraestrutura DevOps (CI/CD).
2. Implementar módulo de OCR com pré-processamento de imagem
   (binarização, correção de perspectiva) para rótulos em pt-BR e en.
3. Integrar API/base de nutrição (ex.: Open Food Facts, Edamam) para
   identificação de ingredientes e contextualização nutricional.
4. Construir fluxos de UI/UX com foco em acessibilidade
   (contraste, fontes escaláveis, navegação por leitor de tela).
5. Configurar pipelines de testes automatizados e deploy contínuo.
6. Realizar testes preliminares de usabilidade e desempenho com
   usuários voluntários, coletando feedback qualitativo.
7. Documentar a experiência (arquitetura, decisões, resultados) em
   formato compatível com publicação científica.

## 6. Princípios Norteadores

- **Acessibilidade primeiro:** decisões de UI não comprometem leitura
  por pessoas com baixa visão ou que usam leitores de tela.
- **Privacidade por padrão:** apenas dados estritamente necessários
  são coletados; o perfil de restrições permanece, sempre que
  possível, no dispositivo.
- **Transparência sobre limites:** o app indica explicitamente quando
  o OCR está incerto e nunca afirma segurança absoluta — o usuário
  é o decisor final.
- **Prototipagem iterativa:** ciclos curtos de implementação, teste
  com usuários e ajuste, em vez de uma única entrega final.
- **Validação acadêmica:** decisões técnicas são fundamentadas em
  evidências da literatura sistematizada na RSL.

## 7. Diferenciais em Relação ao Estado da Arte

Com base nas lacunas mapeadas pela RSL:

- **Integração ponta a ponta:** combina OCR, base nutricional e perfil
  do usuário em um único fluxo — diferentemente da maioria dos
  trabalhos, que abordam essas peças isoladamente.
- **Foco em distúrbios digestivos específicos:** o perfil do usuário
  considera restrições por condição (lactose, glúten, FODMAP, etc.),
  e não apenas registro alimentar genérico.
- **Acessibilidade explícita:** tratada como requisito desde o início
  e validada em testes — não como ajuste pós-implementação.
- **Conformidade ética/legal observada:** decisões de armazenamento
  e consentimento alinhadas à LGPD.

## 8. Escopo de Alto Nível

**No escopo do MVP:**
- Captura de imagens de rótulos.
- Reconhecimento de texto via OCR.
- Identificação básica de ingredientes a partir do texto reconhecido.
- Perfil de usuário com restrições alimentares.
- Geração de alertas personalizados (seguro / atenção / evitar).
- Histórico básico de leituras.
- Backend REST + persistência em nuvem.

**Fora do escopo desta etapa:**
- Treinamento de modelos próprios de visão computacional ou NLP.
- Reconhecimento perfeito de rótulos em condições adversas.
- Autenticação corporativa, monetização ou publicação em lojas.
- Diagnóstico clínico ou recomendações terapêuticas.
- Integração com prontuários eletrônicos.

Detalhamento operacional em
[SCOPE.md](SCOPE.md), [REQUIREMENTS.md](REQUIREMENTS.md) e
[ARCHITECTURE.md](ARCHITECTURE.md).

## 9. Critérios de Sucesso

O protótipo será considerado bem-sucedido se, ao final do ciclo de
Iniciação Tecnológica (PIBITI 2025–2026), atender a:

- **Funcional:** fluxo *foto → OCR → ingredientes → alerta* operacional
  em rótulos reais de supermercado, com pelo menos uma condição
  digestiva contemplada de forma personalizada.
- **Qualidade:** cobertura mínima de testes automatizados em backend
  e camadas críticas do app; pipeline de CI executando a cada PR.
- **Usabilidade:** ao menos 5 usuários voluntários concluem as tarefas
  principais sem intervenção e fornecem feedback estruturado.
- **Acessibilidade:** verificação de contraste, escalonamento de fonte
  e navegação por leitor de tela nas telas principais.
- **Documentação:** arquitetura, decisões e resultados documentados
  em nível adequado para submissão a evento científico.

## 10. Indicadores de Acompanhamento

- Taxa de acerto do OCR em amostra controlada de rótulos (pt-BR).
- Tempo médio entre captura e alerta no dispositivo.
- Número de ingredientes-gatilho corretamente classificados por
  perfil.
- Resultados de tarefas em testes de usabilidade (taxa de conclusão,
  tempo, satisfação).
- Issues de acessibilidade identificadas vs. resolvidas.

## 11. Riscos e Mitigações

| Risco | Mitigação |
|---|---|
| OCR com baixa acurácia em rótulos reais | Pré-processamento de imagem; orientação de captura na UI; indicação explícita de baixa confiança |
| Cobertura insuficiente da base de ingredientes | Combinar mais de uma fonte (Open Food Facts + dicionário local) |
| Falsos negativos em alertas de risco | Mensagem padrão de "não foi possível confirmar segurança"; nunca afirmar "seguro" sem evidência |
| Baixa adesão em testes de usabilidade | Recrutamento via grupos de pacientes; sessões curtas e remotas |
| Dependência de serviços de terceiros | Camada de abstração e modo offline degradado para funcionalidades centrais |

## 12. Horizonte Pós-MVP

Após a validação do protótipo, possíveis evoluções incluem:

- Reconhecimento de tabelas nutricionais (e não apenas lista de
  ingredientes);
- Recomendação ativa de alternativas seguras a um produto rejeitado;
- Integração com nutricionistas (relatórios e compartilhamento
  consentido);
- Expansão para outras condições (diabetes, DRC, fenilcetonúria);
- Modelos próprios de NLP para normalização de ingredientes em
  português.

## 13. Alinhamento Acadêmico

Este protótipo é o produto técnico do plano de trabalho
**PI07741-2024/2 — PIBITI/UFG (2025–2026)**, vinculado ao projeto
*"O Uso de Tecnologias Assistivas para o Auxílio de Pessoas com
Distúrbios Digestivos"*, e dá continuidade à Revisão Sistemática da
Literatura realizada na etapa anterior, transpondo seus achados para
uma solução implementada e avaliada empiricamente.
