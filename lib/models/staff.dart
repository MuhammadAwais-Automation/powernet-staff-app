class Staff {
  final String id;
  final String fullName;
  final String role;
  final String? phone;
  final String? areaId;
  final String? areaName;
  final List<String> areaIds;
  final List<String> areaNames;
  final String? username;
  final String? authUserId;

  Staff({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.areaId,
    this.areaName,
    this.areaIds = const [],
    this.areaNames = const [],
    this.username,
    this.authUserId,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    String? resolvedAreaName = json['area_name'] as String?;
    if (resolvedAreaName == null && json['area'] is Map) {
      resolvedAreaName = (json['area'] as Map)['name'] as String?;
    }
    List<String> resolvedAreaNames = [];
    if (json['areas'] is List) {
      resolvedAreaNames = (json['areas'] as List)
          .map((a) => (a as Map)['name'] as String)
          .toList();
    } else if (resolvedAreaName != null) {
      resolvedAreaNames = [resolvedAreaName];
    }

    return Staff(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      areaId: json['area_id'] as String?,
      areaName: resolvedAreaName,
      areaIds:
          (json['area_ids'] as List?)?.cast<String>() ??
          (json['area_id'] != null ? [json['area_id'] as String] : []),
      areaNames: resolvedAreaNames,
      username: json['username'] as String?,
      authUserId: json['auth_user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'phone': phone,
      'area_id': areaId,
      'area_name': areaName,
      'area_ids': areaIds,
      'area_names': areaNames,
      'username': username,
      'auth_user_id': authUserId,
    };
  }

  String get normalizedRole => normalizeStaffRole(role);

  String get roleLabel {
    switch (normalizedRole) {
      case 'technician':
        return 'Technician';
      case 'recovery_agent':
        return 'Recovery Agent';
      case 'cable_operator':
        return 'Cable Operator';
      case 'field_agent':
        return 'Field Agent';
      case 'complaint_manager':
        return 'Complaint Manager';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  bool get isMobileRole =>
      normalizedRole != 'admin' && normalizedRole != 'complaint_manager';
}

String normalizeStaffRole(String? role) {
  final normalized = (role ?? '').trim().toLowerCase().replaceAll(' ', '_');
  switch (normalized) {
    case 'recovery':
    case 'collector':
    case 'collection_agent':
    case 'recovery_agent':
      return 'recovery_agent';
    case 'technician':
    case 'field_agent':
    case 'cable_operator':
    case 'complaint_manager':
    case 'admin':
      return normalized;
    default:
      return normalized;
  }
}
