import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/primary_button.dart';
import 'accessibility_screen.dart';
import 'barcode_screen.dart';
import 'scan_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header com gradiente
              _buildHeader(context, provider),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status do perfil
                    _buildProfileStatus(context, provider),

                    const SizedBox(height: 24),

                    // Como funciona
                    _buildHowItWorks(),

                    const SizedBox(height: 24),

                    // Botões de ação
                    PrimaryButton(
                      label: 'Escanear Rótulo',
                      icon: Icons.document_scanner_outlined,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    PrimaryButton(
                      label: 'Ler Código de Barras',
                      icon: Icons.qr_code_scanner,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarcodeScreen(),
                        ),
                      ),
                      backgroundColor: AppTheme.primaryGreenDark,
                    ),

                    const SizedBox(height: 12),

                    PrimaryButton(
                      label: 'Histórico de Análises',
                      icon: Icons.history,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      ),
                      backgroundColor: AppTheme.accentOrangeDark,
                    ),

                    const SizedBox(height: 32),

                    // Card informativo
                    _buildInfoCard(),

                    const SizedBox(height: 8),

                    // Privacidade e direito de eliminação (RNF11, RNF14)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Privacidade e dados'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryGreenDark, AppTheme.primaryGreen],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NutriScan',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Assistente nutricional inteligente',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccessibilityScreen(),
                  ),
                ),
                icon: const Icon(
                  Icons.accessibility_new,
                  color: Colors.white,
                  size: 30,
                ),
                tooltip: 'Acessibilidade',
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
                icon: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 32,
                ),
                tooltip: 'Meu Perfil',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_hospital, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestão de Distúrbios Digestivos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.hasProfile
                            ? '${provider.profile.disorders.length} condição(ões) monitorada(s)'
                            : 'Configure seu perfil para começar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatus(BuildContext context, AppProvider provider) {
    if (provider.hasProfile && provider.profile.disorders.isNotEmpty) {
      return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield,
                      color: AppTheme.safeGreenText, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Monitorando: ${provider.profile.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.profile.disorders.map((d) {
                  return Chip(
                    label: Text(d, style: const TextStyle(fontSize: 12)),
                    backgroundColor:
                        AppTheme.warningYellow.withValues(alpha: 0.2),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      color: AppTheme.warningYellow.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppTheme.accentOrangeDark, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configure seu perfil',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Informe seus distúrbios digestivos para receber alertas personalizados ao escanear rótulos.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Como funciona',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildStep(
          number: '1',
          icon: Icons.camera_alt_outlined,
          title: 'Fotografe o rótulo',
          description: 'Tire uma foto ou selecione da galeria o rótulo do alimento.',
        ),
        _buildStep(
          number: '2',
          icon: Icons.text_snippet_outlined,
          title: 'OCR extrai o texto',
          description: 'A tecnologia Tesseract reconhece os ingredientes automaticamente.',
        ),
        _buildStep(
          number: '3',
          icon: Icons.analytics_outlined,
          title: 'Análise inteligente',
          description:
              'O sistema identifica ingredientes problemáticos para seu perfil digestivo.',
        ),
        _buildStep(
          number: '4',
          icon: Icons.notifications_active_outlined,
          title: 'Alertas personalizados',
          description:
              'Receba alertas visuais claros sobre ingredientes que podem causar reações.',
        ),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      color: AppTheme.primaryGreen.withValues(alpha: 0.05),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined,
                    color: AppTheme.primaryGreenDark),
                SizedBox(width: 8),
                Text(
                  'Sobre o Projeto',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryGreenDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Este aplicativo faz parte de um projeto de Iniciação Científica '
              'que utiliza OCR (Reconhecimento Óptico de Caracteres) e '
              'inteligência artificial para auxiliar pessoas com distúrbios '
              'digestivos na identificação de ingredientes em rótulos alimentares.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}