// ---------------------------------------------------------------------------
// App configuration.
//
// This build uses Firebase (Realtime Database + Cloud Messaging) on the free
// Spark plan, plus a Cloudflare Worker for the server-side proximity check.
// Backend credentials live in lib/firebase_options.dart, which you generate by
// running `flutterfire configure` (see SETUP.md). Nothing secret belongs here.
// ---------------------------------------------------------------------------

/// The single bus this demo build tracks. In a real deployment this comes from
/// the logged-in student's / driver's profile.
const String kDemoBusId = 'bus_12';

/// Fallback home/stop location (Thrissur) used before a profile provides one.
const double kFallbackHomeLat = 10.5276;
const double kFallbackHomeLng = 76.2144;

/// Set to true by main() once Firebase.initializeApp succeeds. Services check
/// this so the demo UI still runs (OSM map, screens) even before you've run
/// `flutterfire configure`, instead of crashing on a missing backend.
bool gFirebaseReady = false;

/// This device's FCM registration token, captured at startup and written into
/// the proximity-alert record so the Cloudflare Worker can push to it.
String? gFcmToken;
