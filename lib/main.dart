import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const PowerNetStaffApp());
}

class PowerNetStaffApp extends StatelessWidget {
  const PowerNetStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'PowerNet Staff',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
