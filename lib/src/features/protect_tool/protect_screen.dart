import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/billing_service.dart';
import '../../shared_widgets/tool_card.dart';

class ProtectScreen extends StatefulWidget {
  const ProtectScreen({super.key});

  @override
  State<ProtectScreen> createState() => _ProtectScreenState();
}

class _ProtectScreenState extends State<ProtectScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isProcessing = false;
  double _progress = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect PDF'),
      ),
      body: _isProcessing
          ? Center(
              child: ProcessingProgress(
                progress: _progress,
                message: 'Encrypting your PDF...',
              ),
            )
          : _selectedFilePath == null
              ? EmptyState(
                  icon: Icons.lock,
                  title: 'No File Selected',
                  subtitle: 'Select a PDF to protect with a password',
                  actionLabel: 'Select PDF',
                  onAction: _pickFile,
                )
              : _buildPasswordForm(),
    );
  }

  Widget _buildPasswordForm() {
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
                    color: AppTheme.protectColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: AppTheme.protectColor,
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
                      const Text(
                        'AES-256 Encryption',
                        style: TextStyle(
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
          
          // Password field
          const Text(
            'Set Password',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter a strong password to protect your PDF',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Confirm password field
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Security info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSecurityItem(
                  Icons.shield,
                  'Military-grade AES-256 encryption',
                ),
                const Divider(color: AppTheme.dividerColor),
                _buildSecurityItem(
                  Icons.security,
                  'Your files never leave your device',
                ),
                const Divider(color: AppTheme.dividerColor),
                _buildSecurityItem(
                  Icons.speed,
                  'Powered by Rust for instant encryption',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Protect button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProtect ? _protectPdf : null,
              child: const Text(
                'Protect PDF',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canProtect {
    return _passwordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text &&
        _passwordController.text.length >= 4;
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
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _protectPdf() async {
    if (_selectedFilePath == null) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0;
    });

    try {
      final pdfService = context.read<PdfService>();
      final adService = context.read<AdService>();

      // Simulate progress
      for (var i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _progress = i / 10);
      }

      final result = await pdfService.protectPdf(
        _selectedFilePath!,
        _passwordController.text,
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
            Text('Protected!'),
          ],
        ),
        content: const Text('Your PDF has been protected with a password.'),
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
}
