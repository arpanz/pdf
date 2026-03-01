import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/billing_service.dart';
import '../../shared_widgets/tool_card.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  int _pageCount = 1;
  bool _isProcessing = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Image'),
      ),
      body: _isProcessing
          ? Center(
              child: ProcessingProgress(
                progress: _progress,
                message: 'Converting PDF to images...',
              ),
            )
          : _selectedFilePath == null
              ? EmptyState(
                  icon: Icons.image,
                  title: 'No File Selected',
                  subtitle: 'Select a PDF to convert to high-resolution PNG images',
                  actionLabel: 'Select PDF',
                  onAction: _pickFile,
                )
              : _buildConversionOptions(),
    );
  }

  Widget _buildConversionOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected file info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.pdfToImageColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: AppTheme.pdfToImageColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFileName ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_pageCount page${_pageCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearFile,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Output info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Output Format',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFormatItem('Format', 'PNG (High Resolution)'),
                _buildFormatItem('DPI', '150-300 (High Quality)'),
                _buildFormatItem('One image per', 'Page'),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Convert button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _convertToImages,
              child: Text(
                'Convert to ${_pageCount > 1 ? '${_pageCount} Images' : 'Image'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Change file button
          Center(
            child: TextButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.refresh),
              label: const Text('Change File'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            // Would need PDF library to get actual page count
            _pageCount = 1;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _pageCount = 1;
    });
  }

  Future<void> _convertToImages() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
    });

    try {
      final pdfService = context.read<PdfService>();
      final adService = context.read<AdService>();

      // Simulate progress
      for (var i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        setState(() => _progress = i / 10);
      }

      final outputPath = await pdfService.pdfToImages(_selectedFilePath!);

      setState(() => _progress = 1.0);

      // Show interstitial ad
      if (!context.read<BillingService>().isPro) {
        await adService.showInterstitialAd();
      }

      if (mounted) {
        _showSuccessDialog(outputPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor),
            SizedBox(width: 8),
            Text('Converted!'),
          ],
        ),
        content: Text('PDF converted to $_pageCount image${_pageCount > 1 ? 's' : ''}.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearFile();
            },
            child: const Text('Done'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await Share.share(path);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }
}
