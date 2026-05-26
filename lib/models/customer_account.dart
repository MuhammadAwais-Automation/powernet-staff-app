import 'area.dart';
import 'package_plan.dart';

class CustomerAccount {
  final String id;
  final String customerCode;
  final String? authUserId;
  final String? houseId;
  final String fullName;
  final String? fatherName;
  final String? cnic;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? packageId;
  final String? areaId;
  final String status;
  final String? addressValue;
  final double? dueAmount;
  final String createdAt;
  final Area? area;
  final PackagePlan? package;

  const CustomerAccount({
    required this.id,
    required this.customerCode,
    this.authUserId,
    this.houseId,
    required this.fullName,
    this.fatherName,
    this.cnic,
    this.phone,
    this.whatsapp,
    this.email,
    this.packageId,
    this.areaId,
    required this.status,
    this.addressValue,
    this.dueAmount,
    required this.createdAt,
    this.area,
    this.package,
  });

  factory CustomerAccount.fromJson(Map<String, dynamic> j) => CustomerAccount(
    id: j['id'] as String,
    customerCode: j['customer_code'] as String,
    authUserId: j['auth_user_id'] as String?,
    houseId: j['house_id'] as String?,
    fullName: j['full_name'] as String,
    fatherName: j['father_name'] as String?,
    cnic: j['cnic'] as String?,
    phone: j['phone'] as String?,
    whatsapp: j['whatsapp'] as String?,
    email: j['email'] as String?,
    packageId: j['package_id'] as String?,
    areaId: j['area_id'] as String?,
    status: j['status'] as String,
    addressValue: j['address_value'] as String?,
    dueAmount: (j['due_amount'] as num?)?.toDouble(),
    createdAt: j['created_at'] as String,
    area: j['area'] != null
        ? Area.fromJson(j['area'] as Map<String, dynamic>)
        : null,
    package: j['package'] != null
        ? PackagePlan.fromJson(j['package'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_code': customerCode,
    'auth_user_id': authUserId,
    'house_id': houseId,
    'full_name': fullName,
    'father_name': fatherName,
    'cnic': cnic,
    'phone': phone,
    'whatsapp': whatsapp,
    'email': email,
    'package_id': packageId,
    'area_id': areaId,
    'status': status,
    'address_value': addressValue,
    'due_amount': dueAmount,
    'created_at': createdAt,
    'area': area == null
        ? null
        : {
            'id': area!.id,
            'code': area!.code,
            'name': area!.name,
            'type': area!.type,
            'is_active': area!.isActive,
          },
    'package': package == null
        ? null
        : {
            'id': package!.id,
            'name': package!.name,
            'speed_mbps': package!.speedMbps,
            'default_price': package!.defaultPrice,
            'is_active': package!.isActive,
          },
  };

  String get displayHouseId => houseId ?? addressValue ?? customerCode;
}
