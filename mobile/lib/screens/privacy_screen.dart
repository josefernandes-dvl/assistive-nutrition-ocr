import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/primary_button.dart';

/// Itens do aviso de privacidade, reaproveitados pelo aceite de primeira
/// execução (RNF11) e pela tela de privacidade acessível a qualquer momento
/// (UC04). Manter um texto só evita que as duas versões divirjam.
const List<({IconData icon, String title, String body})> privacyNoticeItems = [
  (
    icon: Icons.phone_android,
    title: 'Seus dados ficam neste aparelho',
    body:
        'Perfil digestivo e histórico de análises são gravados apenas na área '
        'privada do aplicativo. Não há cadastro, login nem envio para a nuvem.',
  ),
  (
    icon: Icons.photo_camera_outlined,
    title: 'A foto do rótulo nunca sai do aparelho',
    body:
        'O reconhecimento de texto acontece no próprio celular. A imagem não é '
        'enviada para nenhum servidor.',
  ),
  (
    icon: Icons.cloud_outlined,
    title: 'O que é enviado ao servidor',
    body:
        'Apenas os nomes de ingredientes lidos e os distúrbios selecionados, '
        'para consultar dados públicos do produto (Open Food Facts). Nenhum '
        'identificador seu acompanha essa consulta.',
  ),
  (
    icon: Icons.delete_outline,
    title: 'Você pode apagar tudo',
    body:
        'Em "Privacidade e dados" existe a opção de apagar perfil e histórico '
        'de uma só vez (LGPD, Art. 18, VI). Desinstalar o app também remove '
        'todos os dados locais.',
  ),
  (
    icon: Icons.medical_information_outlined,
    title: 'Isto não é aconselhamento médico',
    body:
        'O NutriScan é um protótipo acadêmico de apoio à leitura de rótulos. '
        'Ele não diagnostica, não prescreve dieta e não substitui a orientação '
        'de médico ou nutricionista.',
  ),
];

/// Aviso de privacidade da primeira execução, com aceite explícito (RNF11).
/// Enquanto não houver aceite, nenhuma funcionalidade é apresentada.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: const Text(
                  'Antes de começar',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Como o NutriScan trata seus dados de saúde (LGPD — Lei '
                '13.709/2018).',
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              const _PrivacyItemList(),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Entendi e aceito',
                icon: Icons.check_circle_outline,
                semanticHint:
                    'Aceitar o aviso de privacidade e abrir o aplicativo',
                onPressed: () =>
                    context.read<AppProvider>().acceptPrivacyNotice(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Você pode rever este aviso e apagar seus dados a qualquer '
                'momento em "Privacidade e dados".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tela de privacidade acessível pelo app: reexibe o aviso e concentra o
/// direito de eliminação (RF03, RF17, RNF14, UC04).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e dados')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PrivacyItemList(),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: const Text(
                'Apagar meus dados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Remove, deste aparelho, o perfil '
              '${provider.hasProfile ? '(${provider.profile.name}) ' : ''}'
              'e as ${provider.scanHistory.length} análise(s) do histórico. '
              'A ação não pode ser desfeita.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Apagar meus dados',
              icon: Icons.delete_forever,
              backgroundColor: AppTheme.dangerRedText,
              semanticHint:
                  'Apagar perfil e histórico deste aparelho, sem possibilidade '
                  'de desfazer',
              onPressed: () => _confirmErase(context),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                provider.privacyConsentAt == null
                    ? 'Aviso de privacidade ainda não aceito nesta instalação.'
                    : 'Aviso de privacidade aceito nesta instalação.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmErase(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar meus dados'),
        content: const Text(
          'Perfil, histórico e o aceite do aviso de privacidade serão '
          'removidos deste aparelho. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Apagar tudo',
              style: TextStyle(color: AppTheme.dangerRedText),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await provider.eraseAllData();

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Todos os seus dados foram apagados deste aparelho.'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );

    // Sem consentimento, o app volta ao estado de primeira execução.
    navigator.popUntil((route) => route.isFirst);
  }
}

class _PrivacyItemList extends StatelessWidget {
  const _PrivacyItemList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: privacyNoticeItems.map((item) {
        return Semantics(
          label: '${item.title}. ${item.body}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon,
                      color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
