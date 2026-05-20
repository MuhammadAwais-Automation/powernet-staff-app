import 'package:flutter/foundation.dart';
import '../data/bills_repository.dart';
import '../models/bill.dart';

class BillsProvider extends ChangeNotifier {
  final BillsRepository _repo = BillsRepository();

  List<Bill> _bills = [];
  List<Bill> _collectedToday = [];
  bool _loading = false;
  String? _error;

  List<Bill> get bills => _bills;
  List<Bill> get collectedToday => _collectedToday;
  bool get loading => _loading;
  String? get error => _error;

  double get totalDue =>
      _bills.fold(0, (sum, b) => sum + b.remaining);

  double get collectedTodayAmount =>
      _collectedToday.fold(0, (sum, b) => sum + (b.paidAmount ?? 0));

  Future<void> loadPendingByArea(String areaId, String collectorId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.fetchPendingByArea(areaId),
        _repo.fetchCollectedToday(collectorId),
      ]);
      _bills = results[0];
      _collectedToday = results[1];
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> collectPayment({
    required String billId,
    required double amount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
  }) async {
    try {
      await _repo.markPaid(
        billId: billId,
        paidAmount: amount,
        collectorId: collectorId,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
      );
      _bills.removeWhere((b) => b.id == billId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
