import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/billing_service.dart';
import '../../shared_widgets/tool_card.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  final _passwordController = TextEditingController();
  bool _isProcessing = false;
  double _progress = 0;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock PDF'),
      ),
      body: _isProcessing
          ? Center(
              child: ProcessingProgress(
                progress: _progress,
                message: 'Removing password protection...',
              ),
            )
          : _selectedFilePath == null
              ? EmptyState(
                  icon: Icons.lock_open,
                  title: 'No File Selected',
                  subtitle: 'Select a password-protected PDF to unlock',
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
                    color: AppTheme.unlockColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: AppTheme.unlockColor,
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
                        'Password Protected',
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
            'Enter Password',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the current password to unlock the PDF',
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
          
          const SizedBox(height: 32),
          
          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningColor.withAlpha(50)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningColor,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Make sure you have the right password. Multiple failed attempts may lock the file.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Unlock button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _passwordController.text.isNotEmpty ? _unlockPdf : null,
              child: const Text(
                'Unlock PDF',
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
    });
  }

  Future<void> _unlockPdf() async {
    if (_selectedFilePath == null) return;
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the password')),
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

      final result = await pdfService.unlockPdf(
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
            SnackBar(content: Text('Error: ${result.error ?? "Invalid password"}')),
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
            Text('Unlocked!'),
          ],
        ),
        content: const Text('Your PDF has been unlocked successfully.'),
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
