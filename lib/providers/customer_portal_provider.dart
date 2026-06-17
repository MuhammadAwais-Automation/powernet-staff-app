import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/customer_portal_repository.dart';
import '../models/bill.dart';
import '../models/complaint.dart';
import '../models/customer_account.dart';
import '../models/payment_verification.dart';

class CustomerPortalProvider extends ChangeNotifier {
  final CustomerPortalRepository _repo;
  final bool _enableRealtime;
  RealtimeChannel? _billsChannel;
  RealtimeChannel? _complaintsChannel;
  String? _activeCustomerId;
  DateTime? _lastReloadAt;

  List<Bill> _bills = [];
  List<Complaint> _complaints = [];
  List<PaymentVerification> _verifications = [];
  bool _loading = false;
  String? _error;

  CustomerPortalProvider({
    CustomerPortalRepository? repo,
    bool enableRealtime = true,
  }) : _repo = repo ?? CustomerPortalRepository(),
       _enableRealtime = enableRealtime;

  List<Bill> get bills => _bills;
  List<Complaint> get complaints => _complaints;
  List<PaymentVerification> get verifications => _verifications;
  bool get loading => _loading;
  String? get error => _error;

  Bill? get latestBill => _bills.isEmpty ? null : _bills.first;
  int get pendingBillCount => _bills
      .where((b) => b.status == 'pending' || b.status == 'overdue')
      .length;
  double get totalDue => _bills.fold(0, (sum, bill) => sum + bill.remaining);
  int get openComplaintCount =>
      _complaints.where((c) => c.status != 'resolved').length;

  // Verification Helper Getters
  bool isVerificationPending(String billId) {
    return _verifications.any((v) => v.billId == billId && v.status == 'pending');
  }

  bool isVerificationRejected(String billId) {
    return _verifications.any((v) => v.billId == billId && v.status == 'rejected');
  }

  String? getRejectionReason(String billId) {
    try {
      final match = _verifications.firstWhere((v) => v.billId == billId && v.status == 'rejected');
      return match.reviewNote;
    } catch (_) {
      return null;
    }
  }


  Future<void> load(CustomerAccount customer) async {
    _activeCustomerId = customer.id;
    if (_enableRealtime) _ensureRealtime(customer.id);
    _loading = true;
    _error = null;
    notifyListeners();
    Object? billsError;
    Object? complaintsError;
    try {
      _bills = await _repo.fetchBills(customer.id);
    } catch (e) {
      billsError = e;
      _bills = [];
      debugPrint('CustomerPortalProvider bills load failed: $e');
    }
    try {
      _complaints = await _repo.fetchComplaints(customer.id);
    } catch (e) {
      complaintsError = e;
      _complaints = [];
      debugPrint('CustomerPortalProvider complaints load failed: $e');
    }
    try {
      _verifications = await _repo.fetchPaymentVerifications(customer.id);
    } catch (e) {
      debugPrint('CustomerPortalProvider verifications load failed: $e');
      _verifications = [];
    }
    if (billsError != null && complaintsError != null) {
      _error = 'Customer portal data could not be loaded. Please retry.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshActive() async {
    final customerId = _activeCustomerId;
    if (customerId == null) return;
    Object? billsError;
    Object? complaintsError;
    try {
      _bills = await _repo.fetchBills(customerId);
    } catch (e) {
      billsError = e;
      debugPrint('CustomerPortalProvider bills refresh failed: $e');
    }
    try {
      _complaints = await _repo.fetchComplaints(customerId);
    } catch (e) {
      complaintsError = e;
      debugPrint('CustomerPortalProvider complaints refresh failed: $e');
    }
    try {
      _verifications = await _repo.fetchPaymentVerifications(customerId);
    } catch (e) {
      debugPrint('CustomerPortalProvider verifications refresh failed: $e');
    }
    if (billsError == null || complaintsError == null) {
      _error = null;
      notifyListeners();
      return;
    }
    debugPrint(
      'CustomerPortalProvider refresh failed: bills=$billsError complaints=$complaintsError',
    );
  }

  Future<bool> createComplaint({
    required CustomerAccount customer,
    required String issue,
    required String type,
  }) async {
    try {
      final complaint = await _repo.createComplaint(
        customer: customer,
        issue: issue,
        type: type,
      );
      _complaints = [complaint, ..._complaints];
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error =
          'Complaint could not be submitted. Please contact the administrator to verify setup and row-level security permissions.';
      debugPrint('CustomerPortalProvider createComplaint failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitPaymentVerification({
    required String billId,
    required String customerId,
    required double amount,
    required String method,
    required String receiptUrl,
    String? remarks,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.submitPaymentVerification(
        billId: billId,
        customerId: customerId,
        amount: amount,
        method: method,
        receiptUrl: receiptUrl,
        remarks: remarks,
      );
      await refreshActive();
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _error = message.isNotEmpty
          ? message
          : 'Payment verification submission failed. Please try again.';
      debugPrint('submitPaymentVerification failed: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _ensureRealtime(String customerId) {
    if (_billsChannel != null && _complaintsChannel != null) return;
    _billsChannel = supabase
        .channel('customer-bills-$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bills',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (_) => unawaited(_handleRealtimeChange()),
        )
        .subscribe();
    _complaintsChannel = supabase
        .channel('customer-complaints-$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'complaints',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (_) => unawaited(_handleRealtimeChange()),
        )
        .subscribe();
  }

  Future<void> _handleRealtimeChange() async {
    final now = DateTime.now();
    if (_lastReloadAt != null &&
        now.difference(_lastReloadAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastReloadAt = now;
    await refreshActive();
  }

  void clear() {
    _bills = [];
    _complaints = [];
    _verifications = [];
    _activeCustomerId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    final billsChannel = _billsChannel;
    final complaintsChannel = _complaintsChannel;
    if (billsChannel != null) unawaited(supabase.removeChannel(billsChannel));
    if (complaintsChannel != null) {
      unawaited(supabase.removeChannel(complaintsChannel));
    }
    super.dispose();
  }
}
