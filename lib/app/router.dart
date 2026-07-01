import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/customer/customer_bills_screen.dart';
import '../screens/customer/customer_complaints_screen.dart';
import '../screens/customer/customer_home_screen.dart';
import '../screens/customer/customer_profile_screen.dart';
import '../screens/customer/customer_signup_screen.dart';
import '../screens/technician/complaint_list_screen.dart';
import '../screens/technician/complaint_detail_screen.dart';
import '../screens/collector/bill_list_screen.dart';
import '../screens/collector/collect_payment_screen.dart';
import '../screens/collector/follow_up_call_screen.dart';
import '../screens/customer/customer_commitments_screen.dart';
import '../screens/field_agent/customer_list_screen.dart';
import '../screens/field_agent/customer_detail_screen.dart';
import '../screens/cable_operator/co_customer_list_screen.dart';
import '../screens/cable_operator/co_customer_detail_screen.dart';

String _defaultLocationForRole(String? role) {
  return '/home';
}

GoRouter buildRouter(AuthProvider auth, CustomerAuthProvider customerAuth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([auth, customerAuth]),
    redirect: (context, state) {
      if (auth.loading || customerAuth.loading) return null;
      final staffLoggedIn = auth.isLoggedIn;
      final customerLoggedIn = customerAuth.isLoggedIn;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onSplash = loc == '/';
      final onCustomerSignup = loc == '/customer/signup';
      final onCustomerRoute = loc.startsWith('/customer/') && !onCustomerSignup;
      final defaultLocation = _defaultLocationForRole(auth.currentStaff?.role);
      if (!staffLoggedIn &&
          !customerLoggedIn &&
          !onLogin &&
          !onCustomerSignup) {
        return '/login';
      }
      if (customerLoggedIn && (onLogin || onSplash || !onCustomerRoute)) {
        return '/customer/home';
      }
      if (staffLoggedIn &&
          (onLogin || onSplash || onCustomerRoute || onCustomerSignup)) {
        return defaultLocation;
      }
      if (staffLoggedIn && loc == '/home' && defaultLocation != '/home') {
        return defaultLocation;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/customer/signup',
        builder: (context, state) => const CustomerSignupScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: '/customer/home',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/customer/bills',
        builder: (context, state) => const CustomerBillsScreen(),
      ),
      GoRoute(
        path: '/customer/complaints',
        builder: (context, state) => const CustomerComplaintsScreen(),
      ),
      GoRoute(
        path: '/customer/profile',
        builder: (context, state) => const CustomerProfileScreen(),
      ),
      GoRoute(
        path: '/customer/commitments',
        builder: (context, state) => const CustomerCommitmentsScreen(),
      ),

      // Technician routes
      GoRoute(
        path: '/technician/complaints',
        builder: (context, state) => const ComplaintListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                ComplaintDetailScreen(complaintId: state.pathParameters['id']!),
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
            builder: (context, state) =>
                CustomerDetailScreen(customerId: state.pathParameters['id']!),
          ),
        ],
      ),

      // Cable operator routes
      GoRoute(
        path: '/cable-operator/customers',
        builder: (context, state) => const CoCustomerListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                CoCustomerDetailScreen(customerId: state.pathParameters['id']!),
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
            builder: (context, state) =>
                CollectPaymentScreen(billId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: ':id/follow-up',
            builder: (context, state) =>
                FollowUpCallScreen(billId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}
