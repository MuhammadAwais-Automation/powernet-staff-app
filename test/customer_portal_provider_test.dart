import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/data/customer_portal_repository.dart';
import 'package:powernet_staff/models/bill.dart';
import 'package:powernet_staff/models/complaint.dart';
import 'package:powernet_staff/models/customer_account.dart';
import 'package:powernet_staff/providers/customer_portal_provider.dart';

void main() {
  group('CustomerPortalProvider load', () {
    test('keeps bill totals visible when complaints fail to load', () async {
      final provider = CustomerPortalProvider(
        repo: _FakeCustomerPortalRepository(shouldFailFetchComplaints: true),
        enableRealtime: false,
      );

      await provider.load(_customer);

      expect(provider.loading, isFalse);
      expect(provider.error, isNull);
      expect(provider.bills, hasLength(1));
      expect(provider.totalDue, 900);
      expect(provider.complaints, isEmpty);
    });

    test('shows portal error only when all dashboard data fails', () async {
      final provider = CustomerPortalProvider(
        repo: _FakeCustomerPortalRepository(
          shouldFailFetchBills: true,
          shouldFailFetchComplaints: true,
        ),
        enableRealtime: false,
      );

      await provider.load(_customer);

      expect(provider.loading, isFalse);
      expect(provider.error, contains('Customer portal data'));
      expect(provider.bills, isEmpty);
      expect(provider.complaints, isEmpty);
    });
  });

  group('CustomerPortalProvider complaint intake', () {
    test('prepends submitted complaint on success', () async {
      final provider = CustomerPortalProvider(
        repo: _FakeCustomerPortalRepository(),
      );

      final ok = await provider.createComplaint(
        customer: _customer,
        issue: ' Internet disconnects at night ',
        type: 'connectivity',
      );

      expect(ok, isTrue);
      expect(provider.error, isNull);
      expect(provider.complaints, hasLength(1));
      expect(provider.complaints.first.issue, 'Internet disconnects at night');
      expect(provider.complaints.first.assignedTo, isNull);
    });

    test('exposes setup guidance when complaint submit fails', () async {
      final provider = CustomerPortalProvider(
        repo: _FakeCustomerPortalRepository(shouldFailCreate: true),
      );

      final ok = await provider.createComplaint(
        customer: _customer,
        issue: 'Internet disconnects at night',
        type: 'connectivity',
      );

      expect(ok, isFalse);
      expect(provider.complaints, isEmpty);
      expect(provider.error, contains('row-level security'));
    });
  });
}

const _customer = CustomerAccount(
  id: 'customer-1',
  customerCode: 'C-1001',
  fullName: 'Awais Customer',
  status: 'active',
  createdAt: '2026-05-26T00:00:00.000Z',
);

class _FakeCustomerPortalRepository extends CustomerPortalRepository {
  final bool shouldFailFetchBills;
  final bool shouldFailFetchComplaints;
  final bool shouldFailCreate;

  _FakeCustomerPortalRepository({
    this.shouldFailFetchBills = false,
    this.shouldFailFetchComplaints = false,
    this.shouldFailCreate = false,
  });

  @override
  Future<List<Bill>> fetchBills(String customerId) async {
    if (shouldFailFetchBills) {
      throw Exception('permission denied for table bills');
    }
    return [
      Bill(
        id: 'bill-1',
        customerId: customerId,
        amount: 1000,
        paidAmount: 100,
        month: 'May 2026',
        status: 'pending',
        createdAt: '2026-05-01T00:00:00.000Z',
      ),
    ];
  }

  @override
  Future<List<Complaint>> fetchComplaints(String customerId) async {
    if (shouldFailFetchComplaints) {
      throw Exception('permission denied for table staff');
    }
    return [];
  }

  @override
  Future<Complaint> createComplaint({
    required CustomerAccount customer,
    required String issue,
    required String type,
  }) async {
    if (shouldFailCreate) {
      throw Exception('new row violates row-level security policy');
    }
    return Complaint(
      id: 'complaint-1',
      complaintCode: 'CMP-1001',
      customerId: customer.id,
      issue: issue.trim(),
      type: type,
      priority: 'medium',
      status: 'open',
      assignedTo: null,
      openedAt: '2026-05-26T00:00:00.000Z',
      customer: const {
        'id': 'customer-1',
        'full_name': 'Awais Customer',
        'customer_code': 'C-1001',
      },
    );
  }
}
