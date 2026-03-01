import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/billing_service.dart';
import '../../shared_widgets/tool_card.dart';
import '../merge_tool/merge_screen.dart';
import '../split_tool/split_screen.dart';
import '../compress_tool/compress_screen.dart';
import '../protect_tool/protect_screen.dart';
import '../unlock_tool/unlock_screen.dart';
import '../pdf_to_image/pdf_to_image_screen.dart';
import '../history/history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<_ToolItem> _tools = [
    _ToolItem(
      title: 'Merge PDFs',
      subtitle: 'Combine multiple files',
      icon: Icons.merge_type,
      color: AppTheme.mergeColor,
      screen: const MergeScreen(),
    ),
    _ToolItem(
      title: 'Split PDF',
      subtitle: 'Extract pages',
      icon: Icons.content_cut,
      color: AppTheme.splitColor,
      screen: const SplitScreen(),
    ),
    _ToolItem(
      title: 'Compress PDF',
      subtitle: 'Reduce file size',
      icon: Icons.compress,
      color: AppTheme.compressColor,
      screen: const CompressScreen(),
      isPro: true,
    ),
    _ToolItem(
      title: 'Protect',
      subtitle: 'Add password',
      icon: Icons.lock,
      color: AppTheme.protectColor,
      screen: const ProtectScreen(),
    ),
    _ToolItem(
      title: 'Unlock',
      subtitle: 'Remove password',
      icon: Icons.lock_open,
      color: AppTheme.unlockColor,
      screen: const UnlockScreen(),
    ),
    _ToolItem(
      title: 'PDF to Image',
      subtitle: 'Convert to PNG',
      icon: Icons.image,
      color: AppTheme.pdfToImageColor,
      screen: const PdfToImageScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final billingService = context.watch<BillingService>();
    final isPro = billingService.isPro;

    return Scaffold(
      body: SafeArea(
        child: _currentIndex == 0
            ? _buildWorkspace(billingService, isPro)
            : const HistoryScreen(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Workspace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Processed',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace(BillingService billingService, bool isPro) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BatchPDF Studio',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      IconButton(
                        onPressed: () => _showUpgradeDialog(context),
                        icon: const Icon(Icons.star_border),
                        color: AppTheme.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Military-grade PDF processing',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: AnimationLimiter(
            child: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tool = _tools[index];
                  return AnimationConfiguration.staggeredGrid(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    columnCount: 2,
                    child: ScaleAnimation(
                      child: FadeInAnimation(
                        child: ToolCard(
                          title: tool.title,
                          subtitle: tool.subtitle,
                          icon: tool.icon,
                          color: tool.color,
                          isPro: tool.isPro,
                          isLocked: tool.isPro && !isPro,
                          onTap: () => _openTool(context, tool, isPro),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _tools.length,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  void _openTool(BuildContext context, _ToolItem tool, bool isPro) {
    if (tool.isPro && !isPro) {
      _showUpgradeBottomSheet(context);
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => tool.screen),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Pro'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Unlimited file size'),
            Text('• Extreme compression'),
            Text('• No ads'),
            SizedBox(height: 16),
            Text(
              'One-time payment: \$4.99',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<BillingService>().purchasePro();
            },
            child: const Text('Upgrade'),
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
            'Upgrade to Pro to unlock unlimited file size, extreme compression, and remove all ads.',
        onUpgrade: () {
          Navigator.pop(context);
          context.read<BillingService>().purchasePro();
        },
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;
  final bool isPro;

  _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screen,
    this.isPro = false,
  });
}
