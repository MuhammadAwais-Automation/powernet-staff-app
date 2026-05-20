import 'package:flutter/foundation.dart';
import '../data/customers_repository.dart';
import '../models/customer.dart';

class CustomersProvider extends ChangeNotifier {
  final CustomersRepository _repo = CustomersRepository();

  List<Customer> _customers = [];
  List<Customer> _searchResults = [];
  bool _loading = false;
  bool _searching = false;
  String? _error;

  List<Customer> get customers => _customers;
  List<Customer> get searchResults => _searchResults;
  bool get loading => _loading;
  bool get searching => _searching;
  String? get error => _error;

  int get activeCount => _customers.where((c) => c.status == 'active').length;
  int get suspendedCount => _customers.where((c) => c.status == 'suspended').length;
  int get disconnectedCount => _customers.where((c) => c.status == 'disconnected').length;

  Future<void> loadByArea(String areaId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _customers = await _repo.fetchByArea(areaId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query, {String? areaId}) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    try {
      _searchResults = await _repo.search(query, areaId: areaId);
    } catch (_) {
      _searchResults = [];
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}
