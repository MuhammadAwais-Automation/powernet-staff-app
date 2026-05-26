class PackagePlan {
  final String id;
  final String name;
  final int speedMbps;
  final double? defaultPrice;
  final bool isActive;

  const PackagePlan({
    required this.id,
    required this.name,
    required this.speedMbps,
    this.defaultPrice,
    required this.isActive,
  });

  factory PackagePlan.fromJson(Map<String, dynamic> j) => PackagePlan(
    id: j['id'] as String,
    name: j['name'] as String,
    speedMbps: j['speed_mbps'] as int? ?? 0,
    defaultPrice: (j['default_price'] as num?)?.toDouble(),
    isActive: j['is_active'] as bool? ?? true,
  );
}
