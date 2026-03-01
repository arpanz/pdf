import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/billing_service.dart';
import '../../shared_widgets/tool_card.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  int _selectedFileSize = 0;
  int _compressionLevel = 5;
  bool _isProcessing = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    final billingService = context.watch<BillingService>();
    final isPro = billingService.isPro;

    // Show upgrade prompt for non-Pro users
    if (!isPro) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Compress PDF'),
        ),
        body: EmptyState(
          icon: Icons.lock,
          title: 'Pro Feature',
          subtitle: 'Upgrade to Pro to unlock extreme compression for large PDF files',
          actionLabel: 'Upgrade to Pro',
          onAction: () => _showUpgradeBottomSheet(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF'),
      ),
      body: _isProcessing
          ? Center(
              child: ProcessingProgress(
                progress: _progress,
                message: 'Compressing your PDF...',
              ),
            )
          : _selectedFilePath == null
              ? EmptyState(
                  icon: Icons.compress,
                  title: 'No File Selected',
                  subtitle: 'Select a PDF to compress',
                  actionLabel: 'Select PDF',
                  onAction: _pickFile,
                )
              : _buildCompressOptions(),
      bottomNavigationBar: _selectedFilePath != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _compressPdf,
                  child: const Text(
                    'Compress PDF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCompressOptions() {
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
                    color: AppTheme.compressColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: AppTheme.compressColor,
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
                        _formatFileSize(_selectedFileSize),
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
          
          // Compression level slider
          const Text(
            'Compression Level',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Higher compression = smaller file but potentially lower quality',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Text(
                'Light',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              Expanded(
                child: Slider(
                  value: _compressionLevel.toDouble(),
                  min: 1,
                  max: 9,
                  divisions: 8,
                  label: _getCompressionLabel(),
                  onChanged: (value) {
                    setState(() {
                      _compressionLevel = value.toInt();
                    });
                  },
                ),
              ),
              const Text(
                'Extreme',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getCompressionLabel(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Powered by Rust for blazing-fast compression',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCompressionLabel() {
    if (_compressionLevel <= 2) return 'Light';
    if (_compressionLevel <= 4) return 'Moderate';
    if (_compressionLevel <= 6) return 'Strong';
    if (_compressionLevel <= 8) return 'Extreme';
    return 'Maximum';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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
            _selectedFileSize = file.size;
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
      _selectedFileSize = 0;
    });
  }

  Future<void> _compressPdf() async {
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

      final result = await pdfService.compressPdf(
        _selectedFilePath!,
        _compressionLevel,
      );

      if (result.success) {
        setState(() => _progress = 1.0);

        // Show interstitial ad
        if (!context.read<BillingService>().isPro) {
          await adService.showInterstitialAd();
        }

        if (mounted) {
          _showSuccessDialog(result.outputPath);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result.error}')),
          );
        }
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
            Text('Success!'),
          ],
        ),
        content: const Text('Your PDF has been compressed successfully.'),
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
              await Share.shareXFiles([XFile(path)]);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showUpgradeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallBottomSheet(
        title: 'Pro Feature',
        description:
            'Upgrade to Pro to unlock extreme compression for large PDF files.',
        onUpgrade: () {
          Navigator.pop(context);
          context.read<BillingService>().purchasePro();
        },
      ),
    );
  }
}
