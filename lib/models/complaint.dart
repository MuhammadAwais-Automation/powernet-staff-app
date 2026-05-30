class Complaint {
  final String id;
  final String complaintCode;
  final String customerId;
  final String issue;
  final String type;
  final String priority;
  final String status;
  final String? assignedTo;
  final String? assignedAt;
  final String? inProgressAt;
  final String openedAt;
  final String? resolvedAt;
  final String? resolutionNotes;
  final String? hardwareUsed;
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
    this.assignedAt,
    this.inProgressAt,
    required this.openedAt,
    this.resolvedAt,
    this.resolutionNotes,
    this.hardwareUsed,
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
    assignedAt: j['assigned_at'] as String?,
    inProgressAt: j['in_progress_at'] as String?,
    openedAt: j['opened_at'] as String,
    resolvedAt: j['resolved_at'] as String?,
    resolutionNotes: j['resolution_notes'] as String?,
    hardwareUsed: j['hardware_used'] as String?,
    customer: j['customer'] as Map<String, dynamic>?,
    technician: j['technician'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'complaint_code': complaintCode,
    'customer_id': customerId,
    'issue': issue,
    'type': type,
    'priority': priority,
    'status': status,
    'assigned_to': assignedTo,
    'assigned_at': assignedAt,
    'in_progress_at': inProgressAt,
    'opened_at': openedAt,
    'resolved_at': resolvedAt,
    'resolution_notes': resolutionNotes,
    'hardware_used': hardwareUsed,
    'customer': customer,
    'technician': technician,
  };

  Complaint copyWith({
    String? status,
    String? assignedAt,
    String? inProgressAt,
    String? resolvedAt,
    String? resolutionNotes,
    String? hardwareUsed,
  }) => Complaint(
    id: id,
    complaintCode: complaintCode,
    customerId: customerId,
    issue: issue,
    type: type,
    priority: priority,
    status: status ?? this.status,
    assignedTo: assignedTo,
    assignedAt: assignedAt ?? this.assignedAt,
    inProgressAt: inProgressAt ?? this.inProgressAt,
    openedAt: openedAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    hardwareUsed: hardwareUsed ?? this.hardwareUsed,
    customer: customer,
    technician: technician,
  );

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';

  bool get isHigh => priority == 'high';
  bool get isMedium => priority == 'medium';

  String get customerName => customer?['full_name'] as String? ?? '—';
  String get technicianName => technician?['full_name'] as String? ?? '—';
  String get customerCode => customer?['customer_code'] as String? ?? '—';
  String get customerPhone => customer?['phone'] as String? ?? '';
  String get customerAddress => customer?['address_value'] as String? ?? '';
  bool get hasAddress => customerAddress.isNotEmpty;
}
