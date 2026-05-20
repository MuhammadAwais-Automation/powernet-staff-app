import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/technician/complaint_list_screen.dart';
import '../screens/technician/complaint_detail_screen.dart';
import '../screens/collector/bill_list_screen.dart';
import '../screens/collector/collect_payment_screen.dart';
import '../screens/field_agent/customer_list_screen.dart';
import '../screens/field_agent/customer_detail_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      if (auth.loading) return null;
      final loggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onSplash = loc == '/';
      if (!loggedIn && !onLogin && !onSplash) return '/login';
      if (loggedIn && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),

      // Technician routes
      GoRoute(
        path: '/technician/complaints',
        builder: (context, state) => const ComplaintListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => ComplaintDetailScreen(
              complaintId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // Field agent routes
      GoRoute(
        path: '/field-agent/customers',
        builder: (context, state) => const FieldAgentCustomerListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => CustomerDetailScreen(
              customerId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // Collector routes
      GoRoute(
        path: '/collector/bills',
        builder: (context, state) => const BillListScreen(),
        routes: [
          GoRoute(
            path: ':id/collect',
            builder: (context, state) => CollectPaymentScreen(
              billId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
}
