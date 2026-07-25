import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// One row of `bus_roster(bus_id)`: a rider plus whether they are on the bus
/// right now (an open row in `boardings` for the active trip).
class RosterEntry {
  final String profileId;
  final String name;
  final String riderType; // 'student' | 'teacher'
  final String rollNo;
  final String stopName;
  final bool onBus;

  const RosterEntry({
    required this.profileId,
    required this.name,
    required this.riderType,
    required this.rollNo,
    required this.stopName,
    required this.onBus,
  });

  bool get isTeacher => riderType == 'teacher';

  factory RosterEntry.fromJson(Map<String, dynamic> m) => RosterEntry(
        profileId: '${m['profile_id']}',
        name: '${m['full_name']}',
        riderType: '${m['rider_type'] ?? 'student'}',
        rollNo: '${m['roll_no'] ?? '--'}',
        stopName: '${m['stop_name'] ?? '--'}',
        onBus: m['on_bus'] == true,
      );
}

class BusStop {
  final String id;
  final String name;
  final int seq;
  const BusStop({required this.id, required this.name, required this.seq});
}

/// Admin + driver operations. Every call is still checked by RLS or by the
/// SECURITY DEFINER functions, so a non-admin cannot use these.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  SupabaseClient get _sb => Supabase.instance.client;

  Future<List<RosterEntry>> roster(String busId) async {
    if (!gSupabaseReady) return const [];
    final rows = await _sb.rpc('bus_roster', params: {'p_bus': busId});
    return (rows as List)
        .map((r) => RosterEntry.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<BusStop>> stopsForBus(String busId) async {
    if (!gSupabaseReady) return const [];
    final bus =
        await _sb.from('buses').select('route_id').eq('id', busId).maybeSingle();
    final routeId = bus?['route_id'];
    if (routeId == null) return const [];
    final rows = await _sb
        .from('stops')
        .select('id, name, seq')
        .eq('route_id', routeId)
        .order('seq');
    return (rows as List)
        .map((r) => BusStop(
              id: '${r['id']}',
              name: '${r['name']}',
              seq: (r['seq'] as num).toInt(),
            ))
        .toList();
  }

  /// Mark a rider as boarded / not boarded on the active trip.
  Future<void> setOnBus(String profileId, bool onBus) =>
      _sb.rpc('mark_boarding', params: {
        'p_profile': profileId,
        'p_on': onBus,
      });

  /// Creates the auth user + profile + bus assignment through the
  /// `admin-users` Edge Function (the service-role key stays server-side).
  Future<String?> addRider({
    required String email,
    required String password,
    required String fullName,
    required String riderType,
    required String busId,
    String? rollNo,
    String? department,
    String? guardianPhone,
    String? stopId,
    int leadStops = 2,
  }) async {
    try {
      final res = await _sb.functions.invoke('admin-users', body: {
        'action': 'create',
        'email': email,
        'password': password,
        'full_name': fullName,
        'rider_type': riderType,
        'roll_no': rollNo,
        'department': department,
        'guardian_phone': guardianPhone,
        'bus_id': busId,
        'stop_id': stopId,
        'lead_stops': leadStops,
      });
      final data = res.data;
      if (data is Map && data['error'] != null) return '${data['error']}';
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> deleteRider(String profileId) async {
    try {
      final res = await _sb.functions.invoke('admin-users', body: {
        'action': 'delete',
        'profile_id': profileId,
      });
      final data = res.data;
      if (data is Map && data['error'] != null) return '${data['error']}';
      return null;
    } catch (e) {
      return '$e';
    }
  }
}
