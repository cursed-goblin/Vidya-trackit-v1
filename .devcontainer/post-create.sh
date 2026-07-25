#!/usr/bin/env bash
# Runs once when the Codespace is created.
set -euo pipefail

echo "==> Flutter"
flutter --version || true
git config --global --add safe.directory "$(dirname "$(dirname "$(command -v flutter)")")" 2>/dev/null || true

echo "==> Dart packages"
flutter pub get || echo "pub get failed - run it again after the image finishes warming up"

echo "==> Supabase CLI"
npm install -g supabase >/dev/null 2>&1 || echo "npm install supabase failed - use 'npx supabase' instead"

# Build env.json from Codespace secrets so --dart-define-from-file just works.
if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  python3 - <<'PY'
import json, os
with open("env.json", "w") as f:
    json.dump({
        "SUPABASE_URL": os.environ["SUPABASE_URL"],
        "SUPABASE_ANON_KEY": os.environ["SUPABASE_ANON_KEY"],
    }, f, indent=2)
print("Wrote env.json from Codespace secrets")
PY
else
  echo "SUPABASE_URL / SUPABASE_ANON_KEY not set as Codespace secrets."
  echo "Copy env.example.json to env.json and fill it in, or add the secrets"
  echo "under Settings > Codespaces > Repository secrets."
fi

echo "==> Ready. Try: flutter analyze"
