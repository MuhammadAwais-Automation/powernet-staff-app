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

  static VisitType fromValue(String value) => switch (value) {
    'house_locked' => VisitType.houseLocked,
    'promise_to_pay' => VisitType.promiseToPay,
    'refused_to_pay' => VisitType.refusedToPay,
    _ => VisitType.paymentCollected,
  };

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
    createdAt: j['created_at'] as String,
    customer: j['customer'] as Map<String, dynamic>?,
  );

  Bill copyWith({
    double? paidAmount,
    String? status,
    String? collectedBy,
    String? paidAt,
    String? paymentMethod,
    String? paymentNote,
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

  String get customerName => customer?['full_name'] as String? ?? '—';
  String get customerCode => customer?['customer_code'] as String? ?? '—';
  String get customerAddress => customer?['address_value'] as String? ?? '';
  String get customerAddressType => customer?['address_type'] as String? ?? '';

  bool get hasAddress => customerAddress.isNotEmpty;
}
