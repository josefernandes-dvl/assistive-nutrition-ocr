import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late List<String> _selectedDisorders;
  late TextEditingController _customAllergenController;
  late List<String> _customAllergens;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _nameController = TextEditingController(text: provider.profile.name);
    _selectedDisorders = List.from(provider.profile.disorders);
    _customAllergenController = TextEditingController();
    _customAllergens = List.from(provider.profile.customAllergens);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customAllergenController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe seu nome.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final profile = UserProfile(
      name: _nameController.text.trim(),
      disorders: _selectedDisorders,
      customAllergens: _customAllergens,
    );

    context.read<AppProvider>().updateProfile(profile);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil salvo com sucesso!'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );

    Navigator.pop(context);
  }

  void _addCustomAllergen() {
    final text = _customAllergenController.text.trim();
    if (text.isNotEmpty && !_customAllergens.contains(text.toLowerCase())) {
      setState(() {
        _customAllergens.add(text.toLowerCase());
        _customAllergenController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          TextButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Explicação
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Configure seu perfil para que o aplicativo identifique '
                      'automaticamente ingredientes que podem causar reações '
                      'relacionadas aos seus distúrbios digestivos.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Nome
            const Text(
              'Seu Nome',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Digite seu nome',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 28),

            // Distúrbios digestivos
            const Text(
              'Distúrbios Digestivos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecione as condições que se aplicam a você:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),

            ...AppConstants.digestiveDisorders.map((disorder) {
              final isSelected = _selectedDisorders.contains(disorder);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: isSelected
                      ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                      : AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDisorders.remove(disorder);
                        } else {
                          _selectedDisorders.add(disorder);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              disorder,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.verified,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 28),

            // Alérgenos personalizados
            const Text(
              'Alérgenos Personalizados',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Adicione ingredientes específicos que deseja monitorar:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customAllergenController,
                    decoration: const InputDecoration(
                      hintText: 'Ex: amendoim, soja...',
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                    onSubmitted: (_) => _addCustomAllergen(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addCustomAllergen,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            if (_customAllergens.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _customAllergens.map((a) {
                  return Chip(
                    label: Text(a),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() => _customAllergens.remove(a));
                    },
                    backgroundColor:
                        AppTheme.warningYellow.withValues(alpha: 0.2),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 32),

            // Botão salvar
            ElevatedButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Perfil'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
