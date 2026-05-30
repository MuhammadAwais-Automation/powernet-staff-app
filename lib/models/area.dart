class Area {
  final String id;
  final String code;
  final String name;
  final String type;
  final bool isActive;

  const Area({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory Area.fromJson(Map<String, dynamic> j) => Area(
    id: j['id'] as String,
    code: j['code'] as String,
    name: j['name'] as String,
    type: j['type'] as String,
    isActive: j['is_active'] as bool,
  );
}
