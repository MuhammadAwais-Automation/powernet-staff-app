class PaymentVerification {
  final String id;
  final String billId;
  final String customerId;
  final double amount;
  final String method;
  final String receiptUrl;
  final String? customerRemarks;
  final String status;
  final String? reviewNote;
  final String? reviewedBy;
  final String? reviewedAt;
  final String createdAt;

  const PaymentVerification({
    required this.id,
    required this.billId,
    required this.customerId,
    required this.amount,
    required this.method,
    required this.receiptUrl,
    this.customerRemarks,
    required this.status,
    this.reviewNote,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  factory PaymentVerification.fromJson(Map<String, dynamic> j) => PaymentVerification(
    id: j['id'] as String,
    billId: j['bill_id'] as String,
    customerId: j['customer_id'] as String,
    amount: (j['amount'] as num).toDouble(),
    method: j['method'] as String,
    receiptUrl: j['receipt_url'] as String,
    customerRemarks: j['customer_remarks'] as String?,
    status: j['status'] as String,
    reviewNote: j['review_note'] as String?,
    reviewedBy: j['reviewed_by'] as String?,
    reviewedAt: j['reviewed_at'] as String?,
    createdAt: j['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bill_id': billId,
    'customer_id': customerId,
    'amount': amount,
    'method': method,
    'receipt_url': receiptUrl,
    'customer_remarks': customerRemarks,
    'status': status,
    'review_note': reviewNote,
    'reviewed_by': reviewedBy,
    'reviewed_at': reviewedAt,
    'created_at': createdAt,
  };
}
