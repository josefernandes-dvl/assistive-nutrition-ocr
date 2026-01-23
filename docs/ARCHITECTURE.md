# Arquitetura Geral do Sistema

## Visão Geral
O sistema é composto por três camadas principais:
- Aplicativo móvel (Flutter)
- Backend (API REST)
- Serviços externos (OCR e API de Nutrição)

## Fluxo Básico
1. Usuário captura imagem do rótulo
2. Aplicativo realiza OCR local
3. Texto é enviado ao backend
4. Backend consulta API de nutrição
5. Resultado é retornado ao aplicativo

## Observação
A arquitetura foi projetada para simplicidade,
permitindo rápida prototipagem e testes iterativos.
