import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/billing_service.dart';
import '../../shared_widgets/tool_card.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<_SelectedFile> _selectedFiles = [];
  bool _isProcessing = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            TextButton(
              onPressed: _clearFiles,
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: ProcessingProgress(
                progress: _progress,
                message: 'Merging your PDFs...',
              ),
            )
          : _selectedFiles.isEmpty
              ? EmptyState(
                  icon: Icons.merge_type,
                  title: 'No Files Selected',
                  subtitle: 'Select multiple PDFs to merge them into one file',
                  actionLabel: 'Select Files',
                  onAction: _pickFiles,
                )
              : _buildFileList(),
      bottomNavigationBar: _selectedFiles.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _selectedFiles.length >= 2 ? _mergePdfs : null,
                  child: Text(
                    'Merge ${_selectedFiles.length} Files',
                    style: const TextStyle(
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

  Widget _buildFileList() {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _selectedFiles.length,
            onReorder: _reorderFiles,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              return Card(
                key: ValueKey(file.path),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.mergeColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mergeColor,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(file.formattedSize),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeFile(index),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.add),
            label: const Text('Add More Files'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    final billingService = context.read<BillingService>();
    final pdfService = context.read<PdfService>();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            // Check file size limit for free users
            if (!billingService.isPro) {
              final isUnderLimit = await pdfService.checkFileSizeLimit(file.path!);
              if (!isUnderLimit) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${file.name} exceeds 5MB limit. Upgrade to Pro for unlimited file size.',
                      ),
                      action: SnackBarAction(
                        label: 'Upgrade',
                        onPressed: () => _showUpgradeBottomSheet(),
                      ),
                    ),
                  );
                }
                continue;
              }
            }

            setState(() {
              _selectedFiles.add(_SelectedFile(
                path: file.path!,
                name: file.name,
                size: file.size,
              ));
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final file = _selectedFiles.removeAt(oldIndex);
      _selectedFiles.insert(newIndex, file);
    });
  }

  Future<void> _mergePdfs() async {
    if (_selectedFiles.length < 2) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
    });

    try {
      final pdfService = context.read<PdfService>();
      final adService = context.read<AdService>();
      final paths = _selectedFiles.map((f) => f.path).toList();

      // Simulate progress
      for (var i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _progress = i / 10);
      }

      final result = await pdfService.mergePdfs(paths);

      if (result.success) {
        setState(() {
          _progress = 1.0;
        });

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
        content: const Text('Your PDFs have been merged successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearFiles();
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

  void _showUpgradeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallBottomSheet(
        title: 'Upgrade to Pro',
        description:
            'Get unlimited file size, extreme compression, and remove all ads.',
        onUpgrade: () {
          Navigator.pop(context);
          context.read<BillingService>().purchasePro();
        },
      ),
    );
  }
}

class _SelectedFile {
  final String path;
  final String name;
  final int size;

  _SelectedFile({
    required this.path,
    required this.name,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}
