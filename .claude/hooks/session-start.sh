#!/bin/bash
# Phantom Crew — Session Start Hook
# Installs dependencies for the game and relay server so every session is ready to work.
set -euo pipefail

# Only run full install in remote (Claude Code web) sessions
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo '{"async": true, "asyncTimeout": 300000}'

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# ── Relay server dependencies ────────────────────────────────────────────────
RELAY_DIR="$PROJECT_DIR/relay-server"
if [ -f "$RELAY_DIR/package.json" ]; then
  echo "[session-start] Installing relay server npm deps..."
  cd "$RELAY_DIR"
  npm install
  cd "$PROJECT_DIR"
  echo "[session-start] Relay server deps OK"
fi

# ── Flutter project dependencies ─────────────────────────────────────────────
# The Flutter project may be in a subdirectory once scaffolded (phantom-crew/)
# or in the project root. Check both.
FLUTTER_ROOTS=("$PROJECT_DIR" "$PROJECT_DIR/phantom-crew")
for FLUTTER_DIR in "${FLUTTER_ROOTS[@]}"; do
  if [ -f "$FLUTTER_DIR/pubspec.yaml" ]; then
    echo "[session-start] Running flutter pub get in $FLUTTER_DIR..."
    cd "$FLUTTER_DIR"
    flutter pub get 2>/dev/null || echo "[session-start] flutter not available — skipping pub get"
    cd "$PROJECT_DIR"
    break
  fi
done

# ── Python asset generation dependencies ────────────────────────────────────
if [ -f "$PROJECT_DIR/scripts/requirements.txt" ]; then
  echo "[session-start] Installing Python deps for asset generation..."
  pip3 install -q -r "$PROJECT_DIR/scripts/requirements.txt" || true
fi

echo "[session-start] Phantom Crew session ready."
