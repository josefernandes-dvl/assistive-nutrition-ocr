import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/enriched_analysis.dart';
import '../models/scan_result.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

/// Tela de leitura de código de barras (EAN/UPC).
/// - Mobile/Web/macOS: usa câmera via `mobile_scanner`.
/// - Linux/Windows desktop: cai num formulário de entrada manual.
class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  MobileScannerController? _controller;
  final TextEditingController _manualController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;

  bool get _scannerSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    if (_scannerSupported) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
        ],
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcode(String code) async {
    if (_isProcessing) return;
    final cleaned = code.trim();
    if (cleaned.isEmpty) return;

    // Captura provider antes do await para evitar uso de context após async gap
    final provider = context.read<AppProvider>();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    await _controller?.stop();

    try {
      final analysis = await ApiService.analyzeIngredients(
        ingredients: const [],
        disorders: provider.profile.disorders,
        customAllergens: provider.profile.customAllergens,
        barcode: cleaned,
      );

      if (analysis.product == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Produto $cleaned não encontrado no Open Food Facts. Tente outro código ou escaneie o rótulo.';
          _isProcessing = false;
        });
        await _controller?.start();
        return;
      }

      final result = ScanResult(
        rawText: analysis.product!.name ?? 'Produto $cleaned',
        ingredients: analysis.ingredients,
        flaggedIngredients: analysis.flaggedIngredients,
      );

      provider.addScanResult(result);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            scanResult: result,
            enrichment: EnrichmentBundle(
              officialAllergens: analysis.officialAllergens,
              product: analysis.product,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao consultar produto: ${e.toString().replaceFirst('Exception: ', '')}';
        _isProcessing = false;
      });
      await _controller?.start();
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstWhere(
      (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
      orElse: () => const Barcode(),
    );
    final code = raw.rawValue;
    if (code != null && code.isNotEmpty) {
      await _lookupBarcode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar por Código de Barras'),
        actions: [
          if (_scannerSupported && _controller != null)
            IconButton(
              icon: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller!,
                builder: (_, state, __) {
                  final isOn = state.torchState == TorchState.on;
                  return Icon(isOn ? Icons.flash_on : Icons.flash_off);
                },
              ),
              onPressed: () => _controller!.toggleTorch(),
            ),
        ],
      ),
      body: _scannerSupported ? _buildScannerLayout() : _buildManualLayout(),
    );
  }

  Widget _buildScannerLayout() {
    return Stack(
      children: [
        MobileScanner(controller: _controller!, onDetect: _handleDetection),
        Center(
          child: Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Column(
            children: [
              if (_errorMessage != null) _buildErrorBanner(),
              if (_isProcessing)
                PrimaryButton(
                  label: 'Consultando Open Food Facts...',
                  icon: Icons.search,
                  onPressed: () {},
                  isLoading: true,
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aponte para o código de barras do produto',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              // Alternativa: digitar manualmente
              _buildManualEntryCompact(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    'A câmera não está disponível neste sistema (Linux/Windows desktop).\n'
                    'Digite manualmente o código de barras do produto para buscar na '
                    'Open Food Facts.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Código de Barras',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Ex: 7622210449283',
              prefixIcon: Icon(Icons.qr_code),
            ),
            onSubmitted: _lookupBarcode,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            _buildErrorBanner(),
            const SizedBox(height: 12),
          ],
          PrimaryButton(
            label: _isProcessing ? 'Consultando...' : 'Buscar Produto',
            icon: Icons.search,
            onPressed: _isProcessing
                ? () {}
                : () => _lookupBarcode(_manualController.text),
            isLoading: _isProcessing,
          ),
          const SizedBox(height: 32),
          _buildSuggestedCodes(),
        ],
      ),
    );
  }

  Widget _buildManualEntryCompact() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manualController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ou digite o código manualmente',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              onSubmitted: _lookupBarcode,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _lookupBarcode(_manualController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedCodes() {
    final suggestions = [
      ('7894900011517', 'Coca-Cola 2L'),
      ('7622210449283', 'Trakinas chocolate'),
      ('7891000100103', 'Leite Moça Nestlé'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Códigos para teste:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...suggestions.map((s) => InkWell(
              onTap: () {
                _manualController.text = s.$1;
                _lookupBarcode(s.$1);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app,
                        size: 16, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      s.$1,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text('— ${s.$2}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
