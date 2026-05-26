import '../config/supabase_config.dart';
import '../models/area.dart';
import '../models/package_plan.dart';

class CustomerSignupDraft {
  final String fullName;
  final String fatherName;
  final String cnic;
  final String? gender;
  final String? profession;
  final String? rankOrPosition;
  final String? unit;
  final String phone;
  final String? whatsapp;
  final String areaId;
  final String packageId;
  final String houseId;
  final String? streetAddress;
  final String? email;

  const CustomerSignupDraft({
    required this.fullName,
    required this.fatherName,
    required this.cnic,
    this.gender,
    this.profession,
    this.rankOrPosition,
    this.unit,
    required this.phone,
    this.whatsapp,
    required this.areaId,
    required this.packageId,
    required this.houseId,
    this.streetAddress,
    this.email,
  });

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'father_name': fatherName.trim(),
    'cnic': cnic.trim(),
    'gender': gender,
    'profession': profession,
    'rank_or_position': rankOrPosition,
    'unit': unit,
    'phone': phone.trim(),
    'whatsapp': whatsapp?.trim().isEmpty == true ? null : whatsapp?.trim(),
    'area_id': areaId,
    'package_id': packageId,
    'house_id': houseId.trim(),
    'street_address': streetAddress?.trim().isEmpty == true
        ? null
        : streetAddress?.trim(),
    'email': email?.trim().isEmpty == true ? null : email?.trim(),
    'status': 'pending',
  };
}

class CustomerSignupRepository {
  Future<List<Area>> fetchAreas() async {
    final res = await supabase
        .from('areas')
        .select('id, code, name, type, is_active')
        .eq('is_active', true)
        .order('name');
    return (res as List)
        .map((j) => Area.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<PackagePlan>> fetchPackages() async {
    final res = await supabase
        .from('packages')
        .select('id, name, speed_mbps, default_price, is_active')
        .eq('is_active', true)
        .order('speed_mbps');
    return (res as List)
        .map((j) => PackagePlan.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> submit(CustomerSignupDraft draft) async {
    await supabase.from('customer_signup_requests').insert(draft.toJson());
  }
}
