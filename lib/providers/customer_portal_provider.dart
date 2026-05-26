import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/customer_portal_repository.dart';
import '../models/bill.dart';
import '../models/complaint.dart';
import '../models/customer_account.dart';

class CustomerPortalProvider extends ChangeNotifier {
  final CustomerPortalRepository _repo;
  RealtimeChannel? _billsChannel;
  RealtimeChannel? _complaintsChannel;
  String? _activeCustomerId;
  DateTime? _lastReloadAt;

  List<Bill> _bills = [];
  List<Complaint> _complaints = [];
  bool _loading = false;
  String? _error;

  CustomerPortalProvider({CustomerPortalRepository? repo})
    : _repo = repo ?? CustomerPortalRepository();

  List<Bill> get bills => _bills;
  List<Complaint> get complaints => _complaints;
  bool get loading => _loading;
  String? get error => _error;

  Bill? get latestBill => _bills.isEmpty ? null : _bills.first;
  int get pendingBillCount => _bills
      .where((b) => b.status == 'pending' || b.status == 'overdue')
      .length;
  double get totalDue => _bills.fold(0, (sum, bill) => sum + bill.remaining);
  int get openComplaintCount =>
      _complaints.where((c) => c.status != 'resolved').length;

  Future<void> load(CustomerAccount customer) async {
    _activeCustomerId = customer.id;
    _ensureRealtime(customer.id);
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _bills = await _repo.fetchBills(customer.id);
      _complaints = await _repo.fetchComplaints(customer.id);
    } catch (e) {
      _error = 'Customer portal data load nahi ho saka. Retry karein.';
      debugPrint('CustomerPortalProvider load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshActive() async {
    final customerId = _activeCustomerId;
    if (customerId == null) return;
    try {
      _bills = await _repo.fetchBills(customerId);
      _complaints = await _repo.fetchComplaints(customerId);
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('CustomerPortalProvider refresh failed: $e');
    }
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
      _error = 'Complaint submit nahi ho saki. Dobara try karein.';
      debugPrint('CustomerPortalProvider createComplaint failed: $e');
      notifyListeners();
      return false;
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
