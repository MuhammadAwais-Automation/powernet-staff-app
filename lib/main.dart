import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app/router.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/bills_provider.dart';
import 'providers/complaint_queue_provider.dart';
import 'providers/customers_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const PowerNetStaffApp());
}

class PowerNetStaffApp extends StatefulWidget {
  const PowerNetStaffApp({super.key});

  @override
  State<PowerNetStaffApp> createState() => _PowerNetStaffAppState();
}

class _PowerNetStaffAppState extends State<PowerNetStaffApp> {
  late final AuthProvider _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider();
    _router = buildRouter(_auth);
    _auth.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider(create: (_) => BillsProvider()),
        ChangeNotifierProvider(create: (_) => ComplaintQueueProvider()),
        ChangeNotifierProvider(create: (_) => CustomersProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, child) => MaterialApp.router(
          title: 'PowerNet Staff',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: ThemeMode.system,
          routerConfig: _router,
        ),
      ),
    );
  }
}
