import '../models/area.dart';
import '../config/supabase_config.dart';

class AreasRepository {
  Future<List<Area>> fetchAll() async {
    final res = await supabase
        .from('areas')
        .select('id, code, name, type, is_active')
        .eq('is_active', true)
        .order('name');
    return (res as List)
        .map((j) => Area.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Area?> fetchById(String id) async {
    final res = await supabase
        .from('areas')
        .select('id, code, name, type, is_active')
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Area.fromJson(res);
  }
}
