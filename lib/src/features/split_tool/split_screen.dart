import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/billing_service.dart';
import '../../shared_widgets/tool_card.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  int _pageCount = 1;
  final Set<int> _selectedPages = {};
  bool _isProcessing = false;
  double _progress = 0;
  bool _isAllSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
      ),
      body: _isProcessing
          ? Center(
              child: ProcessingProgress(
                progress: _progress,
                message: 'Extracting pages...',
              ),
            )
          : _selectedFilePath == null
              ? EmptyState(
                  icon: Icons.content_cut,
                  title: 'No File Selected',
                  subtitle: 'Select a PDF to split',
                  actionLabel: 'Select PDF',
                  onAction: _pickFile,
                )
              : _buildPageSelector(),
      bottomNavigationBar: _selectedFilePath != null && _selectedPages.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _splitPdf,
                  child: Text(
                    'Extract ${_selectedPages.length} Pages',
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

  Widget _buildPageSelector() {
    return Column(
      children: [
        // Selected file info
        Container(
          margin: const EdgeInsets.all(16),
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
                  color: AppTheme.splitColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: AppTheme.splitColor,
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
                      '$_pageCount pages',
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
        
        // Selection controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isAllSelected
                    ? '${_selectedPages.length} pages selected'
                    : '${_selectedPages.length} of $_pageCount selected',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
              TextButton(
                onPressed: _toggleSelectAll,
                child: Text(_isAllSelected ? 'Deselect All' : 'Select All'),
              ),
            ],
          ),
        ),
        
        // Page grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _pageCount,
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final isSelected = _selectedPages.contains(pageNumber);
              
              return GestureDetector(
                onTap: () => _togglePage(pageNumber),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.splitColor
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.splitColor
                          : AppTheme.dividerColor,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$pageNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Add more files button
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.refresh),
            label: const Text('Change File'),
          ),
        ),
      ],
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
            _selectedPages.clear();
            _isAllSelected = false;
            // Assume single page for simplicity - would need PDF library for actual count
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
      _selectedPages.clear();
      _pageCount = 1;
    });
  }

  void _togglePage(int pageNumber) {
    setState(() {
      if (_selectedPages.contains(pageNumber)) {
        _selectedPages.remove(pageNumber);
      } else {
        _selectedPages.add(pageNumber);
      }
      _isAllSelected = _selectedPages.length == _pageCount;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedPages.clear();
        _isAllSelected = false;
      } else {
        for (var i = 1; i <= _pageCount; i++) {
          _selectedPages.add(i);
        }
        _isAllSelected = true;
      }
    });
  }

  Future<void> _splitPdf() async {
    if (_selectedFilePath == null || _selectedPages.isEmpty) return;

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

      final result = await pdfService.splitPdf(
        _selectedFilePath!,
        _selectedPages.toList(),
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
        content: Text('Extracted ${_selectedPages.length} pages successfully.'),
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
