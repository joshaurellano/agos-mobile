import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url:     dotenv.env['SUPABASE_URL']      ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const AgosApp(),
    ),
  );
}

class AgosApp extends StatelessWidget {
  const AgosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.bgCard,
        ),
        useMaterial3: true,
      ),
      home: Consumer<AuthService>(
        builder: (_, auth, __) {
          if (auth.isLoading) {
            return const Scaffold(
              backgroundColor: AppColors.bgDeep,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            );
          }
          return auth.currentUser != null
              ? const MainShell()
              : const LoginScreen();
        },
      ),
    );
  }
}

class AppColors {
  static const bgDeep     = Color(0xFF091729);
  static const bgDark     = Color(0xFF0D1F3C);
  static const bgMid      = Color(0xFF112240);
  static const bgCard     = Color(0xFF0F1E38);
  static const bgBorder   = Color(0xFF1E3A5F);
  static const accent     = Color(0xFF38BDF8);
  static const green      = Color(0xFF22C55E);
  static const yellow     = Color(0xFFEAB308);
  static const orange     = Color(0xFFF97316);
  static const red        = Color(0xFFEF4444);
  static const textPri    = Color(0xFFE2EAF5);
  static const textSec    = Color(0xFF8DA4BE);
  static const textMuted  = Color(0xFF4A6080);
}
