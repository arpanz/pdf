import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/services/pdf_service.dart';
import 'src/core/services/ad_service.dart';
import 'src/core/services/billing_service.dart';
import 'src/features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.primaryColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const BatchPdfApp());
}

class BatchPdfApp extends StatelessWidget {
  const BatchPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => PdfService()),
        ChangeNotifierProvider(create: (_) => BillingService()..initialize()),
        Provider(create: (_) => AdService()..initialize()),
      ],
      child: MaterialApp(
        title: 'BatchPDF Studio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );
  }
}
