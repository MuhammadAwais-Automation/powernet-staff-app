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
  final String? teamId;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? technician;
  final Map<String, dynamic>? team;

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
    this.teamId,
    this.customer,
    this.technician,
    this.team,
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
    teamId: j['team_id'] as String?,
    customer: j['customer'] as Map<String, dynamic>?,
    technician: j['technician'] as Map<String, dynamic>?,
    team: j['team'] as Map<String, dynamic>?,
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
    'team_id': teamId,
    'customer': customer,
    'technician': technician,
    'team': team,
  };

  Complaint copyWith({
    String? status,
    String? assignedTo,
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
    assignedTo: assignedTo ?? this.assignedTo,
    assignedAt: assignedAt ?? this.assignedAt,
    inProgressAt: inProgressAt ?? this.inProgressAt,
    openedAt: openedAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    hardwareUsed: hardwareUsed ?? this.hardwareUsed,
    teamId: teamId,
    customer: customer,
    technician: technician,
    team: team,
  );

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';

  bool get isHigh => priority == 'high';
  bool get isMedium => priority == 'medium';

  String get customerName => customer?['full_name'] as String? ?? '—';

  bool get isAssigned =>
      assignedTo != null ||
      teamId != null ||
      technician != null ||
      team != null;

  String get assigneeLabel {
    final techName = technician?['full_name'] as String?;
    if (techName != null && techName.trim().isNotEmpty) return techName;

    final teamLabel = team?['name'] as String?;
    if (teamLabel != null && teamLabel.trim().isNotEmpty) {
      return '$teamLabel (Team)';
    }

    if (assignedTo != null || teamId != null) return 'Assigned';

    return 'Not Assigned';
  }

  String get technicianName {
    if (technician != null) {
      return technician?['full_name'] as String? ?? '—';
    }
    if (team != null) {
      return team?['name'] as String? ?? '—';
    }
    return '—';
  }

  String get teamName => team?['name'] as String? ?? '—';
  String get customerCode => customer?['customer_code'] as String? ?? '—';
  String get customerPhone => customer?['phone'] as String? ?? '';
  String get customerAddress => customer?['address_value'] as String? ?? '';
  bool get hasAddress => customerAddress.isNotEmpty;
}
