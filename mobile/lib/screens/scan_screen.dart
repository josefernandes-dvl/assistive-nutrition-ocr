import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/enriched_analysis.dart';
import '../models/scan_result.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/ocr_service.dart';
import '../utils/text_parser.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _barcodeController = TextEditingController();
  File? _selectedImage;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _tesseractAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkTesseract();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _checkTesseract() async {
    final available = await OcrService.isTesseractAvailable();
    if (mounted) {
      setState(() => _tesseractAvailable = available);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erro ao selecionar imagem: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Câmera não disponível neste dispositivo.');
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    // Captura provider antes do await para evitar uso de context após async gap
    final provider = context.read<AppProvider>();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 1. Executa OCR na imagem
      final outcome = await OcrService.extractText(_selectedImage!.path);
      final rawText = outcome.text;

      // 2. Limpa e extrai ingredientes
      final cleanText = TextParser.cleanOcrText(rawText);
      final ingredientNames = TextParser.extractIngredientNames(cleanText);

      // Se o OCR rodou mas a qualidade está claramente ruim, avisa o usuário
      // em vez de mostrar lixo na tela. Sugere o fluxo de barcode.
      if (outcome.isLowQuality || ingredientNames.isEmpty) {
        setState(() {
          _errorMessage = 'A foto não tem qualidade suficiente para extrair '
              'os ingredientes corretamente. Dicas: enquadre apenas a lista de '
              'ingredientes, mantenha a câmera paralela ao rótulo e use boa '
              'iluminação. Para produtos cadastrados, prefira "Ler Código de Barras".';
          _isProcessing = false;
        });
        return;
      }

      // 3. Analisa ingredientes contra o perfil do usuário
      final ingredients = TextParser.analyzeIngredients(
        ingredientNames,
        provider.profile.disorders,
        customAllergens: provider.profile.customAllergens,
      );

      // 4. Separa ingredientes flagged
      final flagged = ingredients.where((i) => i.isFlagged).toList();

      // 4b. Avisos de "contém traços de / pode conter" relevantes para o perfil
      final traceTerms = TextParser.extractTraceWarnings(rawText);
      final traceWarnings = TextParser.analyzeTraces(
        traceTerms,
        provider.profile.disorders,
        customAllergens: provider.profile.customAllergens,
      );

      // 5. Cria resultado local (offline-first)
      final result = ScanResult(
        rawText: rawText,
        ingredients: ingredients,
        flaggedIngredients: flagged,
        imagePath: _selectedImage!.path,
      );

      // 6. Enriquecimento opcional via backend (Open Food Facts).
      //    Falha silenciosa se backend offline — usuário ainda vê análise local.
      EnrichmentBundle? enrichment;
      final barcodeOptional = _barcodeController.text.trim();
      try {
        final enriched = await ApiService.analyzeIngredients(
          ingredients: ingredientNames,
          disorders: provider.profile.disorders,
          customAllergens: provider.profile.customAllergens,
          barcode: barcodeOptional.isEmpty ? null : barcodeOptional,
        );
        enrichment = EnrichmentBundle(
          officialAllergens: enriched.officialAllergens,
          product: enriched.product,
        );
      } catch (_) {
        enrichment = null;
      }

      // 7. Salva no histórico local
      provider.addScanResult(result);

      if (!mounted) return;

      // 8. Navega para tela de resultados
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            scanResult: result,
            enrichment: enrichment,
            traceWarnings: traceWarnings,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Rótulo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status do Tesseract
            _buildTesseractStatus(),

            const SizedBox(height: 20),

            // Área de preview da imagem
            _buildImagePreview(),

            const SizedBox(height: 24),

            // Botões de seleção de imagem
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeria',
                    onTap: _pickFromGallery,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Câmera',
                    onTap: _pickFromCamera,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Campo OPCIONAL: código de barras para enriquecer com OFF
            _buildBarcodeOptional(),

            const SizedBox(height: 20),

            // Erro
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.dangerRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.dangerRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.dangerRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botão de processar
            PrimaryButton(
              label: _isProcessing ? 'Processando OCR...' : 'Analisar Rótulo',
              icon: Icons.analytics_outlined,
              onPressed: (_selectedImage != null && !_isProcessing && _tesseractAvailable)
                  ? _processImage
                  : () {},
              isLoading: _isProcessing,
            ),

            const SizedBox(height: 24),

            // Dicas
            _buildTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildTesseractStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _tesseractAvailable
            ? AppTheme.safeGreen.withValues(alpha: 0.1)
            : AppTheme.warningYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _tesseractAvailable ? Icons.check_circle : Icons.warning_amber,
            color: _tesseractAvailable
                ? AppTheme.safeGreen
                : AppTheme.warningYellow,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tesseractAvailable
                  ? 'OCR pronto (Tesseract com suporte a Português)'
                  : 'Tesseract OCR não detectado.\nInstale: sudo apt install tesseract-ocr tesseract-ocr-por',
              style: TextStyle(
                fontSize: 13,
                color: _tesseractAvailable
                    ? AppTheme.safeGreen
                    : AppTheme.accentOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selectedImage != null
              ? AppTheme.primaryGreen
              : Colors.grey.shade300,
          width: 2,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: _selectedImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => setState(() => _selectedImage = null),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'Selecione uma imagem do rótulo',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use a galeria ou câmera abaixo',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBarcodeOptional() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code, size: 18, color: AppTheme.primaryGreen),
              SizedBox(width: 6),
              Text(
                'Código de barras (opcional)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Informe para ver Nutri-Score, NOVA e alérgenos oficiais do produto.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _barcodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Ex: 7622210449283',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: AppTheme.primaryGreen),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTips() {
    return Card(
      elevation: 0,
      color: AppTheme.primaryGreen.withValues(alpha: 0.05),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dicas para melhor resultado:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            _TipItem(text: 'Posicione o rótulo sob boa iluminação'),
            _TipItem(text: 'Evite sombras e reflexos sobre o texto'),
            _TipItem(text: 'Mantenha a câmera estável e focada'),
            _TipItem(text: 'Enquadre apenas a lista de ingredientes'),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.accentOrange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
