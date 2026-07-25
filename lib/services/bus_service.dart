import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/bus_location.dart';
import '../models/proximity_alert.dart';

/// Supabase-backed replacement for the old Firebase RtdbService.
///
///   /liveLocations/{busId}            -> public.bus_locations (realtime)
///   /proximityAlerts/{busId}/{userId} -> public.alert_subscriptions (RLS)
class BusService {
  BusService._();
  static final BusService instance = BusService._();

  SupabaseClient get _sb => Supabase.instance.client;

  /// Live stream of one bus's position. One row per bus, so the stream emits
  /// the row itself (or null while the bus is not on a trip).
  Stream<BusLocation?> watchBus(String busId) {
    if (!gSupabaseReady) return const Stream.empty();
    return _sb
        .from('bus_locations')
        .stream(primaryKey: ['bus_id'])
        .eq('bus_id', busId)
        .map((rows) =>
            rows.isEmpty ? null : BusLocation.fromJson(rows.first));
  }

  /// One-time fetch used to seed the map before the stream warms up.
  Future<BusLocation?> fetchBus(String busId) async {
    if (!gSupabaseReady) return null;
    final row = await _sb
        .from('bus_locations')
        .select()
        .eq('bus_id', busId)
        .maybeSingle();
    return row == null ? null : BusLocation.fromJson(row);
  }

  /// Driver-side write. Goes through record_location(), which checks that the
  /// caller really is the assigned driver and also appends history.
  Future<void> writeLocation(String busId, BusLocation loc) async {
    if (!gSupabaseReady) return;
    await _sb.rpc('record_location', params: {
      'p_bus': busId,
      'p_lat': loc.lat,
      'p_lng': loc.lng,
      'p_speed': loc.speed,
      'p_heading': loc.heading,
      'p_recorded_at': loc.updatedAt.toUtc().toIso8601String(),
    });
  }

  Future<String?> startTrip(String busId) async {
    if (!gSupabaseReady) return null;
    final id = await _sb.rpc('start_trip', params: {'p_bus': busId});
    return id as String?;
  }

  Future<void> endTrip(String busId) async {
    if (!gSupabaseReady) return;
    await _sb.rpc('end_trip', params: {'p_bus': busId});
  }

  // ---- proximity alerts ----

  Future<ProximityAlert?> loadMyAlert() async {
    if (!gSupabaseReady) return null;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _sb
        .from('alert_subscriptions')
        .select()
        .eq('profile_id', uid)
        .maybeSingle();
    return row == null ? null : ProximityAlert.fromJson(row);
  }

  Future<void> setProximityAlert(ProximityAlert a) async {
    if (!gSupabaseReady) return;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    await _sb.from('alert_subscriptions').upsert({
      ...a.toJson(),
      'profile_id': uid,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> disableProximityAlert() async {
    if (!gSupabaseReady) return;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    await _sb
        .from('alert_subscriptions')
        .update({'enabled': false})
        .eq('profile_id', uid);
  }
}
