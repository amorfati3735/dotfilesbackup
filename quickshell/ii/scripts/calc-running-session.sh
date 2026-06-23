#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/calc-focus"
TOKEN_FILE="$CACHE_DIR/id_token"
UID_FILE="$CACHE_DIR/user_uid"

mkdir -p "$CACHE_DIR"

# Source config
source "$CONFIG_DIR/calc-firebase.env"
source "$CONFIG_DIR/calc-firebase.auth"

# Helper: sign in and cache token
sign_in() {
  local resp
  resp=$(curl -s \
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FIREBASE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$FIREBASE_EMAIL\",\"password\":\"$FIREBASE_PASSWORD\",\"returnSecureToken\":true}")
  
  local token uid
  token=$(echo "$resp" | jq -r '.idToken // empty')
  uid=$(echo "$resp" | jq -r '.localId // empty')
  
  if [[ -z "$token" || -z "$uid" ]]; then
    >&2 echo "Auth failed: $(echo "$resp" | jq -c '.error // .')"
    exit 1
  fi
  
  echo "$token" > "$TOKEN_FILE"
  echo "$uid" > "$UID_FILE"
  TOKEN="$token"
  USER_UID="$uid"
}

# Read cached token
TOKEN=""
USER_UID=""
if [[ -f "$TOKEN_FILE" && -f "$UID_FILE" ]]; then
  TOKEN=$(cat "$TOKEN_FILE")
  USER_UID=$(cat "$UID_FILE")
fi

# If no cached token, sign in
if [[ -z "$TOKEN" || -z "$USER_UID" ]]; then
  sign_in
fi

# Fetch running session — on 401 (expired), re-auth and retry once
DB_URL="${FIREBASE_DATABASE_URL%/}"
resp=$(curl -s -w "\n%{http_code}" \
  "$DB_URL/users/$USER_UID/runningSession.json?auth=$TOKEN")

http_code=$(echo "$resp" | tail -1)
body=$(echo "$resp" | sed '$d')

if [[ "$http_code" = "401" ]]; then
  sign_in
  resp=$(curl -s -w "\n%{http_code}" \
    "$DB_URL/users/$USER_UID/runningSession.json?auth=$TOKEN")
  http_code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')
fi

if [[ "$http_code" != "200" ]]; then
  >&2 echo "Fetch failed: HTTP $http_code"
  exit 1
fi

echo "$body"