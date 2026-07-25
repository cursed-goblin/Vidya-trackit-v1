import 'bus_service.dart';

/// Deprecated compatibility shim.
///
/// The Firebase Realtime Database layer is gone; every call now goes to
/// [BusService] (Supabase). Kept so older screens keep compiling - new code
/// should use `BusService.instance` directly, and this file can be deleted
/// once `lib/screens/live_map_screen.dart` is updated.
@Deprecated('Use BusService.instance (Supabase) instead')
class RtdbService {
  RtdbService._();
  static BusService get instance => BusService.instance;
}
