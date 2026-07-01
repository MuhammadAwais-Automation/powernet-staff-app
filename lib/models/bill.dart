enum VisitType {
  paymentCollected,
  houseLocked,
  promiseToPay,
  refusedToPay;

  String get label => switch (this) {
    VisitType.paymentCollected => 'Payment Collected',
    VisitType.houseLocked => 'House Locked',
    VisitType.promiseToPay => 'Promise to Pay',
    VisitType.refusedToPay => 'Refused to Pay',
  };

  String get value => switch (this) {
    VisitType.paymentCollected => 'payment_collected',
    VisitType.houseLocked => 'house_locked',
    VisitType.promiseToPay => 'promise_to_pay',
    VisitType.refusedToPay => 'refused_to_pay',
  };

  static VisitType fromValue(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    return switch (normalized) {
      'payment_collected' => VisitType.paymentCollected,
      'house_locked' => VisitType.houseLocked,
      'promise_to_pay' => VisitType.promiseToPay,
      'refused_to_pay' => VisitType.refusedToPay,
      _ => VisitType.houseLocked,
    };
  }

  bool get requiresAmount => this == VisitType.paymentCollected;
  bool get isVisitOnly => this != VisitType.paymentCollected;
}

class Bill {
  final String id;
  final String customerId;
  final double amount;
  final double? paidAmount;
  final String month;
  final String status;
  final String? collectedBy;
  final String? paidAt;
  final String? receiptNo;
  final String? paymentMethod;
  final String? paymentNote;
  final String? paymentSource;
  final String? promisedDate;
  final String createdAt;
  final Map<String, dynamic>? customer;

  const Bill({
    required this.id,
    required this.customerId,
    required this.amount,
    this.paidAmount,
    required this.month,
    required this.status,
    this.collectedBy,
    this.paidAt,
    this.receiptNo,
    this.paymentMethod,
    this.paymentNote,
    this.paymentSource,
    this.promisedDate,
    required this.createdAt,
    this.customer,
  });

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    id: j['id'] as String,
    customerId: j['customer_id'] as String,
    amount: (j['amount'] as num).toDouble(),
    paidAmount: (j['paid_amount'] as num?)?.toDouble(),
    month: j['month'] as String,
    status: j['status'] as String,
    collectedBy: j['collected_by'] as String?,
    paidAt: j['paid_at'] as String?,
    receiptNo: j['receipt_no'] as String?,
    paymentMethod: j['payment_method'] as String?,
    paymentNote: j['payment_note'] as String?,
    paymentSource: j['payment_source'] as String?,
    promisedDate: j['promised_date'] as String?,
    createdAt: j['created_at'] as String,
    customer: j['customer'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'amount': amount,
    'paid_amount': paidAmount,
    'month': month,
    'status': status,
    'collected_by': collectedBy,
    'paid_at': paidAt,
    'receipt_no': receiptNo,
    'payment_method': paymentMethod,
    'payment_note': paymentNote,
    'payment_source': paymentSource,
    'promised_date': promisedDate,
    'created_at': createdAt,
    'customer': customer,
  };

  Bill copyWith({
    double? paidAmount,
    String? status,
    String? collectedBy,
    String? paidAt,
    String? paymentMethod,
    String? paymentNote,
    String? paymentSource,
    String? promisedDate,
  }) => Bill(
    id: id,
    customerId: customerId,
    amount: amount,
    paidAmount: paidAmount ?? this.paidAmount,
    month: month,
    status: status ?? this.status,
    collectedBy: collectedBy ?? this.collectedBy,
    paidAt: paidAt ?? this.paidAt,
    receiptNo: receiptNo,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentNote: paymentNote ?? this.paymentNote,
    paymentSource: paymentSource ?? this.paymentSource,
    promisedDate: promisedDate ?? this.promisedDate,
    createdAt: createdAt,
    customer: customer,
  );

  double get remaining => amount - (paidAmount ?? 0);
  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';
  bool get hasPartialPayment => !isPaid && (paidAmount ?? 0) > 0;
  double get collectionProgress =>
      amount <= 0 ? 0 : ((paidAmount ?? 0) / amount).clamp(0, 1).toDouble();
  String get collectionStatus => hasPartialPayment ? 'partial' : status;
  String get paymentSourceLabel {
    switch (paymentSource) {
      case 'office':
        return 'Paid in Office';
      case 'agent':
        return 'Collected by Agent';
      case 'customer':
        return 'Paid by Customer';
      case 'manual':
        return 'Manual Entry';
      default:
        return 'Payment Source Pending';
    }
  }

  String get customerName => customer?['full_name'] as String? ?? '—';
  String get customerCode => customer?['customer_code'] as String? ?? '—';
  String get customerAddress => customer?['address_value'] as String? ?? '';
  String get customerAddressType => customer?['address_type'] as String? ?? '';

  bool get hasAddress => customerAddress.isNotEmpty;
  String? get customerAreaId => customer?['area_id'] as String?;
  bool get isPromiseToPay => paymentNote == VisitType.promiseToPay.value;
}

class CustomerBillLedger {
  final String customerId;
  final List<Bill> bills;

  const CustomerBillLedger({required this.customerId, required this.bills});

  factory CustomerBillLedger.fromBills(List<Bill> bills) {
    if (bills.isEmpty) {
      throw ArgumentError('CustomerBillLedger requires at least one bill');
    }
    final sorted = [...bills]..sort(_compareNewestFirst);
    return CustomerBillLedger(
      customerId: sorted.first.customerId,
      bills: sorted,
    );
  }

  static List<CustomerBillLedger> groupBills(List<Bill> bills) {
    final grouped = <String, List<Bill>>{};
    for (final bill in bills) {
      grouped.update(
        bill.customerId,
        (existing) => [...existing, bill],
        ifAbsent: () => [bill],
      );
    }

    final ledgers = grouped.entries
        .map((entry) => CustomerBillLedger.fromBills(entry.value))
        .where((ledger) => ledger.totalRemaining > 0)
        .toList();
    ledgers.sort((a, b) {
      final billCompare = _compareNewestFirst(a.currentBill, b.currentBill);
      if (billCompare != 0) return billCompare;
      return a.customerId.compareTo(b.customerId);
    });
    return ledgers;
  }

  List<Bill> get openBills =>
      bills.where((bill) => !bill.isPaid && bill.remaining > 0).toList();
  Bill get currentBill => openBills.isNotEmpty ? openBills.first : bills.first;
  List<Bill> get previousBills => openBills.skip(1).toList();
  int get billCount => openBills.length;
  String get customerName => currentBill.customerName;
  String get customerCode => currentBill.customerCode;
  String get customerAddress => currentBill.customerAddress;
  String get customerAddressType => currentBill.customerAddressType;
  String? get customerAreaId => currentBill.customerAreaId;
  bool get hasAddress => currentBill.hasAddress;
  bool get isOverdue => openBills.any((bill) => bill.isOverdue);
  bool get hasPartialPayment => totalPaid > 0 && totalRemaining > 0;
  double get totalAmount => totalPaid + totalRemaining;
  double get totalPaid =>
      bills.fold(0, (sum, bill) => sum + (bill.paidAmount ?? 0));
  double get totalRemaining =>
      openBills.fold(0, (sum, bill) => sum + bill.remaining);
  double get currentDue => currentBill.remaining;
  double get previousDue =>
      previousBills.fold(0, (sum, bill) => sum + bill.remaining);
  double get collectionProgress =>
      totalAmount <= 0 ? 0 : (totalPaid / totalAmount).clamp(0, 1).toDouble();

  String get monthRange {
    if (openBills.length <= 1) return currentBill.month;
    return '${openBills.last.month} to ${currentBill.month}';
  }

  String get collectionStatus {
    if (totalRemaining <= 0) return 'paid';
    if (isOverdue) return 'overdue'; // overdue takes priority — shown in Overdue tab
    if (hasPartialPayment) return 'partial';
    return currentBill.status;
  }


  static int _compareNewestFirst(Bill a, Bill b) {
    final monthCompare = _monthRank(b.month).compareTo(_monthRank(a.month));
    if (monthCompare != 0) return monthCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  static int _monthRank(String value) {
    final trimmed = value.trim();
    final iso = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(trimmed);
    if (iso != null) {
      final year = int.tryParse(iso.group(1)!) ?? 0;
      final month = int.tryParse(iso.group(2)!) ?? 0;
      return year * 12 + month;
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final month = _monthNumber(parts.first);
      final year = int.tryParse(parts.last) ?? 0;
      if (month > 0 && year > 0) return year * 12 + month;
    }

    return 0;
  }

  static int _monthNumber(String value) {
    switch (value.toLowerCase()) {
      case 'jan':
      case 'january':
        return 1;
      case 'feb':
      case 'february':
        return 2;
      case 'mar':
      case 'march':
        return 3;
      case 'apr':
      case 'april':
        return 4;
      case 'may':
        return 5;
      case 'jun':
      case 'june':
        return 6;
      case 'jul':
      case 'july':
        return 7;
      case 'aug':
      case 'august':
        return 8;
      case 'sep':
      case 'sept':
      case 'september':
        return 9;
      case 'oct':
      case 'october':
        return 10;
      case 'nov':
      case 'november':
        return 11;
      case 'dec':
      case 'december':
        return 12;
      default:
        return 0;
    }
  }
}
