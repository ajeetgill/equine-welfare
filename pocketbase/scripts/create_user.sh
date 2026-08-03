#!/usr/bin/env bash
# Create an app user (assessor) as the superuser. Usage:
#   ./scripts/create_user.sh <superuser-email> <superuser-password> <new-user-email> <new-user-password>
set -euo pipefail
PB_URL="${PB_URL:-http://localhost:8090}"

SUTOKEN=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$1\",\"password\":\"$2\"}" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])')

curl -s -X POST "$PB_URL/api/collections/users/records" \
  -H "Content-Type: application/json" \
  -H "Authorization: $SUTOKEN" \
  -d "{\"email\":\"$3\",\"password\":\"$4\",\"passwordConfirm\":\"$4\",\"verified\":true}"
echo
