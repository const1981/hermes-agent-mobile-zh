#!/usr/bin/env bash
# Secret-scan gate for the Hermes Android APP.
#
# Decompiles the built APK with apktool and flags HIGH-CONFIDENCE hardcoded
# secrets in smali. Exits 1 (FAIL the gate) if any hit is found; 0 if clean.
#
# Design notes (why this is value-aware, not word-matching):
#   - The APP legitimately contains the WORDS "api_key"/"token"/"secret" as smali
#     field/method names and as runtime ${VAR} .env references. A naive grep on
#     those words would false-positive and break the build every time.
#   - So we only FAIL on secret *shapes* (sk-, ghp_, AKIA..., JWT, PEM private
#     keys) that are actual const-string values.
#   - API keys MUST live in ~/.hermes/.env as ${VAR} references (never literal
#     in Dart/Kotlin); this gate enforces that at release time.
#
# Usage: secret_scan.sh <path-to-apk>
set -u

# --- path conversion for native Windows java (CI/Linux needs no change) ---
# Git Bash passes POSIX paths (/d/foo); java.exe (native Windows) can't read
# them, so on Msys/Cygwin we convert to Windows form (D:\foo). On
# Linux CI, paths pass through unchanged.
IS_WIN=0
case "$(uname -o 2>/dev/null)" in
  *Msys*|*Cygwin*|*Windows*) IS_WIN=1 ;;
esac
winpath() {
  if [ "$IS_WIN" -eq 1 ]; then
    if command -v cygpath >/dev/null 2>&1; then
      cygpath -w "$1"
    else
      printf '%s' "$1" | sed -E 's|^/([a-zA-Z])/|\U\1:/|; s|/|\\|g'
    fi
  else
    printf '%s' "$1"
  fi
}

APK="${1:-app-release.apk}"
HERE="$(cd "$(dirname "$0")" && pwd)"
JAR="${HERE}/apktool.jar"
DEC="${HERE}/dec_tmp"

if [ ! -f "$APK" ]; then
  echo "ERROR: APK not found: $APK"
  exit 2
fi

# Fetch apktool if missing (CI / first local run). Pinned version.
if [ ! -f "$JAR" ]; then
  echo "apktool.jar missing, downloading v3.0.2 ..."
  curl -sSL -o "$JAR" "https://github.com/iBotPeaches/Apktool/releases/download/v3.0.2/apktool_3.0.2.jar" \
    || { echo "ERROR: failed to download apktool"; exit 2; }
fi

rm -rf "$DEC"

# Resolve a java executable robustly (CI has `java` on PATH; locally we may
# only have the bundled JBR at /d/ProgramData/apk/jbr).
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  JAVA="${JAVA_HOME}/bin/java"
elif command -v java >/dev/null 2>&1; then
  JAVA=java
else
  JAVA=""
  for cand in /d/ProgramData/apk/jbr/bin/java /usr/bin/java /opt/java/bin/java; do
    [ -x "$cand" ] && JAVA="$cand" && break
  done
fi
if [ -z "$JAVA" ]; then
  echo "ERROR: java not found (set JAVA_HOME or put java on PATH)"
  rm -rf "$DEC"; exit 2
fi

"$JAVA" -jar "$(winpath "$JAR")" d -q "$(winpath "$APK")" -o "$(winpath "$DEC")" || { echo "ERROR: apktool decompile failed"; rm -rf "$DEC"; exit 2; }

# --- High-confidence hardcoded-secret shapes (const-string values only) ---
SHAPES='sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
HITS=$(grep -rEoh "const-string[^\"]*\"[^\"]*(${SHAPES})[^\"]*\"" "$DEC"/smali* 2>/dev/null)

# --- Informational (non-failing) audit: key-name const-strings, for visibility ---
AUDIT=$(grep -rEoh "const-string[^\"]*\"(api[_-]?key|secret|token|password|passwd|private[_-]?key)[^\"]*\"" "$DEC"/smali* 2>/dev/null | grep -v '\${' | head -20)

rm -rf "$DEC"

if [ -n "$HITS" ]; then
  echo "=============================================="
  echo "FAIL: potential hardcoded secret(s) found in smali:"
  echo "$HITS"
  echo "=============================================="
  exit 1
fi

echo "PASS: no hardcoded high-confidence secrets found in $APK"
if [ -n "$AUDIT" ]; then
  echo "--- (informational) key-name const-strings present (expected: .env \${VAR} refs / field names) ---"
  echo "$AUDIT" | head -10
fi
exit 0
