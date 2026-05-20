import 'area.dart';

class Customer {
  final String id;
  final String customerCode;
  final String? username;
  final String fullName;
  final String? cnic;
  final String? phone;
  final String? packageId;
  final bool iptv;
  final String addressType;
  final String? addressValue;
  final String? areaId;
  final String? connectionDate;
  final double? dueAmount;
  final String? onuNumber;
  final String status;
  final String? disconnectedDate;
  final String? reconnectedDate;
  final String? remarks;
  final String createdAt;
  final Area? area;

  const Customer({
    required this.id,
    required this.customerCode,
    this.username,
    required this.fullName,
    this.cnic,
    this.phone,
    this.packageId,
    required this.iptv,
    required this.addressType,
    this.addressValue,
    this.areaId,
    this.connectionDate,
    this.dueAmount,
    this.onuNumber,
    required this.status,
    this.disconnectedDate,
    this.reconnectedDate,
    this.remarks,
    required this.createdAt,
    this.area,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        customerCode: j['customer_code'] as String,
        username: j['username'] as String?,
        fullName: j['full_name'] as String,
        cnic: j['cnic'] as String?,
        phone: j['phone'] as String?,
        packageId: j['package_id'] as String?,
        iptv: j['iptv'] as bool? ?? false,
        addressType: j['address_type'] as String? ?? 'text',
        addressValue: j['address_value'] as String?,
        areaId: j['area_id'] as String?,
        connectionDate: j['connection_date'] as String?,
        dueAmount: (j['due_amount'] as num?)?.toDouble(),
        onuNumber: j['onu_number'] as String?,
        status: j['status'] as String,
        disconnectedDate: j['disconnected_date'] as String?,
        reconnectedDate: j['reconnected_date'] as String?,
        remarks: j['remarks'] as String?,
        createdAt: j['created_at'] as String,
        area: j['area'] != null
            ? Area.fromJson(j['area'] as Map<String, dynamic>)
            : null,
      );

  String get displayId => username ?? customerCode;
}
