import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  print('URL: $supabaseUrl');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
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
        scaffoldBackgroundColor: AppColors.blueDark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.blueCard,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              backgroundColor: AppColors.blueDark,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            );
          }
          if (auth.currentUser != null) return const MainLayout();
          return const LoginScreen();
        },
      ),
    );
  }
}

class AppColors {
  static const Color blueDark   = Color(0xFF0D1F3C);
  static const Color blueDeep   = Color(0xFF091729);
  static const Color blueMid    = Color(0xFF112240);
  static const Color blueCard   = Color(0xFF0F1E38);
  static const Color blueBorder = Color(0xFF1E3A5F);
  static const Color accent     = Color(0xFF38BDF8);
  static const Color green      = Color(0xFF22C55E);
  static const Color yellow     = Color(0xFFEAB308);
  static const Color orange     = Color(0xFFF97316);
  static const Color red        = Color(0xFFEF4444);
  static const Color textPrimary   = Color(0xFFE2EAF5);
  static const Color textSecondary = Color(0xFF8DA4BE);
  static const Color textMuted     = Color(0xFF4A6080);
}