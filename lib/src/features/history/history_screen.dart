import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdfx/pdfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/pdf_file.dart';
import '../../core/services/pdf_service.dart';
import '../../shared_widgets/tool_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PdfFile> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final pdfService = context.read<PdfService>();
      final files = await pdfService.getProcessedFiles();
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processed Files'),
        actions: [
          if (_files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFiles,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const EmptyState(
                  icon: Icons.folder_open,
                  title: 'No Files Yet',
                  subtitle: 'Processed files will appear here',
                )
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return _buildFileCard(file);
                    },
                  ),
                ),
    );
  }

  Widget _buildFileCard(PdfFile file) {
    return Dismissible(
      key: Key(file.path),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppTheme.accentColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.share, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Share
          await Share.shareXFiles([XFile(file.path)]);
          return false;
        } else {
          // Delete
          return await _confirmDelete(file);
        }
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          final pdfService = context.read<PdfService>();
          await pdfService.deleteFile(file.path);
          _loadFiles();
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _openPdf(file),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getActionColor(file.action).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActionIcon(file.action),
                    color: _getActionColor(file.action),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            file.formattedSize,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            file.action,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(file.processedDate),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptions(file),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'merged':
        return Icons.merge_type;
      case 'split':
        return Icons.content_cut;
      case 'compressed':
        return Icons.compress;
      case 'protected':
        return Icons.lock;
      case 'unlocked':
        return Icons.lock_open;
      default:
        return Icons.picture_as_pdf;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'merged':
        return AppTheme.mergeColor;
      case 'split':
        return AppTheme.splitColor;
      case 'compressed':
        return AppTheme.compressColor;
      case 'protected':
        return AppTheme.protectColor;
      case 'unlocked':
        return AppTheme.unlockColor;
      default:
        return AppTheme.accentColor;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _openPdf(PdfFile file) async {
    try {
      final document = await PdfDocument.openFile(file.path);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              document: document,
              fileName: file.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  Future<bool> _confirmDelete(PdfFile file) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete File'),
            content: Text('Are you sure you want to delete "${file.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showOptions(PdfFile file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                _openPdf(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(context);
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.errorColor),
              title: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () async {
                Navigator.pop(context);
                if (await _confirmDelete(file)) {
                  final pdfService = context.read<PdfService>();
                  await pdfService.deleteFile(file.path);
                  _loadFiles();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final PdfDocument document;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.document,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: PdfView(
        document: document,
        builders: PdfViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorBuilder: (_, error) => Center(
            child: Text(error.toString()),
          ),
        ),
      ),
    );
  }
}
