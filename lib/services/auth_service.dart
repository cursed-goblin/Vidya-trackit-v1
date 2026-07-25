import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/staff.dart';
import '../models/student.dart';

/// Supabase Auth + profile loading.
///
/// Roles live in `public.profiles.role`:
///   rider  - students and teachers (told apart by profiles.rider_type)
///   driver - shares the live location of the bus assigned to them
///   admin  - manages riders and sees who is on the bus
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Student? student;
  Staff? staff;
  String role = 'guest';
  String? uid;

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';

  SupabaseClient get _sb => Supabase.instance.client;

  /// Mirror the access token into SharedPreferences so the background GPS
  /// isolate can post to PostgREST, and keep it fresh on every refresh.
  void watchSession() {
    _sb.auth.onAuthStateChange.listen((data) async {
      final prefs = await SharedPreferences.getInstance();
      final token = data.session?.accessToken;
      if (token == null) {
        await prefs.remove(kPrefAccessToken);
      } else {
        await prefs.setString(kPrefAccessToken, token);
      }
    });
  }

  /// Returns null on success or a user-facing error message.
  Future<String?> signIn(String email, String password) async {
    if (!gSupabaseReady) {
      return 'Backend not configured. See SUPABASE_SETUP.md.';
    }
    try {
      final res = await _sb.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      uid = res.user?.id;
      if (uid == null) return 'Sign-in failed. Please try again.';
      await loadProfile();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not sign in: $e';
    }
  }

  /// Loads the profile row plus bus/route/stop details for the current user.
  Future<void> loadProfile() async {
    final id = uid ?? _sb.auth.currentUser?.id;
    if (id == null) return;
    uid = id;

    final p = await _sb
        .from('profiles')
        .select('role, rider_type, full_name, roll_no, department, '
            'guardian_phone')
        .eq('id', id)
        .maybeSingle();
    if (p == null) {
      role = 'guest';
      return;
    }
    role = '${p['role']}';

    if (role == 'driver' || role == 'admin') {
      final bus = await _sb
          .from('buses')
          .select('id, reg_no, routes(name)')
          .eq('driver_id', id)
          .maybeSingle();
      staff = Staff(
        staffId: id,
        name: '${p['full_name']}',
        busId: '${bus?['id'] ?? kDemoBusId}',
        busNumber: '${bus?['reg_no'] ?? '--'}',
        routeName: '${(bus?['routes'] as Map?)?['name'] ?? '--'}',
      );
      return;
    }

    final rb = await _sb
        .from('rider_bus')
        .select('bus_id, stop_id, lead_stops, home_lat, home_lng, '
            'stops(name, lat, lng), buses(reg_no, routes(name))')
        .eq('profile_id', id)
        .maybeSingle();
    final stop = rb?['stops'] as Map?;
    final bus = rb?['buses'] as Map?;
    student = Student(
      id: id,
      name: '${p['full_name']}',
      rollNo: '${p['roll_no'] ?? '--'}',
      department: '${p['department'] ?? '--'}',
      riderType: '${p['rider_type'] ?? 'student'}',
      boardingStop: '${stop?['name'] ?? '--'}',
      stopId: rb?['stop_id'] as String?,
      leadStops: (rb?['lead_stops'] as num?)?.toInt() ?? 2,
      homeLat: (rb?['home_lat'] as num?)?.toDouble() ??
          (stop?['lat'] as num?)?.toDouble() ??
          kFallbackHomeLat,
      homeLng: (rb?['home_lng'] as num?)?.toDouble() ??
          (stop?['lng'] as num?)?.toDouble() ??
          kFallbackHomeLng,
      busId: '${rb?['bus_id'] ?? kDemoBusId}',
      busNumber: '${bus?['reg_no'] ?? '--'}',
      routeName: '${(bus?['routes'] as Map?)?['name'] ?? '--'}',
      guardianMasked: _mask('${p['guardian_phone'] ?? ''}'),
    );
  }

  String _mask(String phone) {
    if (phone.length < 6) return phone.isEmpty ? '--' : phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
  }

  Future<void> logout() async {
    if (gSupabaseReady) {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
    }
    student = null;
    staff = null;
    role = 'guest';
    uid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefAccessToken);
  }

  // -------------------------------------------------------------------------
  // Offline demo fallbacks - only used when the app is built without Supabase
  // credentials, so the UI can still be shown. They grant no data access.
  // -------------------------------------------------------------------------
  Student loginStudentDemo() {
    student = const Student(
      id: 'demo-student',
      name: 'Rahul Menon',
      rollNo: 'VEC-CS-118',
      department: 'Computer Science',
      boardingStop: 'Punkunnam',
      homeLat: kFallbackHomeLat,
      homeLng: kFallbackHomeLng,
      busId: kDemoBusId,
      busNumber: 'KL-08 AV 4412',
      routeName: 'Route 12 - Thrissur Town to Vidya Engineering College',
      guardianMasked: '+91 98****43',
    );
    role = 'rider';
    return student!;
  }

  Staff loginStaffDemo() {
    staff = const Staff(
      staffId: 'demo-driver',
      name: 'Suresh K',
      busId: kDemoBusId,
      busNumber: 'KL-08 AV 4412',
      routeName: 'Route 12 - Thrissur Town to Vidya Engineering College',
    );
    role = 'driver';
    return staff!;
  }
}
