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

  double get remaining => amount - (paidAmount ?? 0);
  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';

  String get customerName => customer?['full_name'] as String? ?? '—';
  String get customerCode => customer?['customer_code'] as String? ?? '—';
}
