class Staff {
  final String id;
  final String fullName;
  final String role;
  final String? phone;
  final String? areaId;
  final String? areaName;
  final String? username;
  final String? authUserId;

  Staff({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.areaId,
    this.areaName,
    this.username,
    this.authUserId,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      areaId: json['area_id'] as String?,
      areaName: json['area_name'] as String?,
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
      'username': username,
      'auth_user_id': authUserId,
    };
  }

  String get roleLabel {
    switch (role) {
      case 'technician':
        return 'Technician';
      case 'recovery_agent':
        return 'Recovery Agent';
      case 'helper_technician':
        return 'Helper Technician';
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

  bool get isMobileRole => role != 'admin' && role != 'complaint_manager';
}
