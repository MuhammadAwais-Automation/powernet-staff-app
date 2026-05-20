class Complaint {
  final String id;
  final String complaintCode;
  final String customerId;
  final String issue;
  final String type;
  final String priority;
  final String status;
  final String? assignedTo;
  final String openedAt;
  final String? resolvedAt;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? technician;

  const Complaint({
    required this.id,
    required this.complaintCode,
    required this.customerId,
    required this.issue,
    required this.type,
    required this.priority,
    required this.status,
    this.assignedTo,
    required this.openedAt,
    this.resolvedAt,
    this.customer,
    this.technician,
  });

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: j['id'] as String,
        complaintCode: j['complaint_code'] as String,
        customerId: j['customer_id'] as String,
        issue: j['issue'] as String,
        type: j['type'] as String,
        priority: j['priority'] as String,
        status: j['status'] as String,
        assignedTo: j['assigned_to'] as String?,
        openedAt: j['opened_at'] as String,
        resolvedAt: j['resolved_at'] as String?,
        customer: j['customer'] as Map<String, dynamic>?,
        technician: j['technician'] as Map<String, dynamic>?,
      );

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';

  bool get isHigh => priority == 'high';
  bool get isMedium => priority == 'medium';

  String get customerName => customer?['full_name'] as String? ?? '—';
  String get technicianName => technician?['full_name'] as String? ?? '—';
}
