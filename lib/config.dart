// ---------------------------------------------------------------------------
// App configuration.
//
// Backend: Supabase (Postgres + Auth + Realtime + Edge Functions).
// Push notifications: Firebase Cloud Messaging only - Supabase has no push
// service, and a phone with the app closed needs FCM/APNs to be woken.
//
// The Supabase URL and anon key are public by design (RLS protects the data),
// but they are still passed at build time so forks don't inherit your project:
//   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//               --dart-define=SUPABASE_ANON_KEY=eyJ...
// Never put the service-role key in the app.
// ---------------------------------------------------------------------------

const String kSupabaseUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String kSupabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

/// Fallback bus for the demo build, used when a profile has no assignment.
const String kDemoBusId = 'bus_12';

/// Fallback home/stop location (Thrissur) used before a profile provides one.
const double kFallbackHomeLat = 10.5276;
const double kFallbackHomeLng = 76.2144;

/// True once Supabase.initialize succeeded. Services check this so the UI still
/// runs (OSM map, screens) when the app is built without credentials.
bool gSupabaseReady = false;

/// True once Firebase.initializeApp succeeded (FCM only).
bool gFirebaseReady = false;

/// This device's FCM registration token, stored on the alert subscription so
/// the Edge Function can push to it.
String? gFcmToken;

// SharedPreferences keys shared with the background GPS isolate. Writing these
// BEFORE starting the service avoids the old race where the isolate started
// with a hard-coded bus id because the setBus message arrived too early.
const String kPrefBusId = 'trackit.busId';
const String kPrefAccessToken = 'trackit.accessToken';
