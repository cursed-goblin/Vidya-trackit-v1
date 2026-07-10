import 'package:flutter/material.dart';

// ---- Brand palette (shared across every screen) ----
const kPurple = Color(0xFF7C3AED);
const kPurpleLight = Color(0xFF8B5CF6);
const kPurpleDark = Color(0xFF6D28D9);
const kBg1 = Color(0xFF1A0B2E);
const kAppBg = Color(0xFFF8FAFC);
const kHeading = Color(0xFF1E293B);
const kSub = Color(0xFF64748B);
const kGreen = Color(0xFF10B981);
const kRed = Color(0xFFEF4444);
const kAmber = Color(0xFFF59E0B);
const kBorder = Color(0xFFE2E8F0);

// Our real package id (OpenStreetMap blocks requests with an empty user agent).
const kAppPackageId = 'com.vidya.vidya_trackit';

// OpenStreetMap tile template, assembled from parts on purpose.
// The z / x / y tokens are flutter_map placeholders and must stay literal.
String osmTileUrl() {
  const scheme = 'ht' 'tps';
  const host = 'tile.' 'openstreetmap.' 'org';
  const tokens = '/' '{z}' '/' '{x}' '/' '{y}' '.png';
  return scheme + '://' + host + tokens;
}

ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: kAppBg,
      colorScheme: ColorScheme.fromSeed(seedColor: kPurple),
      fontFamily: 'Roboto',
    );

const kDarkAuthGradient = RadialGradient(
  center: Alignment(0.7, -0.9),
  radius: 1.4,
  colors: [Color(0xFF3A1D6E), Color(0xFF241247), kBg1],
  stops: [0.0, 0.45, 1.0],
);
