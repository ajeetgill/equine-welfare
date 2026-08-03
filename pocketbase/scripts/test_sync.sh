#!/usr/bin/env bash
# End-to-end test of the sync endpoint. Usage:
#   ./scripts/test_sync.sh <user-email> <user-password>
set -euo pipefail
PB_URL="${PB_URL:-http://localhost:8090}"

TOKEN=$(curl -s -X POST "$PB_URL/api/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$1\",\"password\":\"$2\"}" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["token"])')

PAYLOAD='{
  "assessment": {"externalId": "11111111-2222-3333-4444-555555555555", "vetName": "Dr. Test", "farmName": "Test Farm", "visitDate": 1754100000000, "isComplete": true, "sideNotes": "test note"},
  "horses": [{"externalId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "name": "Testy", "age": 5, "ageUnit": "years", "color": "bay", "sex": "mare", "breed": "Arabian", "otherBreed": "", "timeOnFarm": 2, "timeUnit": "years", "bcsScore": 5, "notes": "", "isHorse": true}],
  "sections": [{"sectionNumber": 1, "title": "Nutrition", "isApplicable": true, "infoIconClicks": 3, "subsections": [{"name": "Feed", "requirements": [{"text": "Adequate feed", "complianceStatus": "Compliant", "nonComplianceReason": ""}]}]}]
}'

echo "-- guest request (expect 401):"
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -d "$PAYLOAD"

echo "-- first sync:"
ID1=$(curl -s -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d "$PAYLOAD" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["assessmentId"])')
echo "assessmentId: $ID1"

echo "-- re-sync (expect SAME id — upsert, not duplicate):"
ID2=$(curl -s -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d "$PAYLOAD" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["assessmentId"])')
echo "assessmentId: $ID2"
[ "$ID1" = "$ID2" ] && echo "PASS: upsert kept the same record" || { echo "FAIL: duplicate assessment"; exit 1; }

echo "-- horse count after re-sync (expect 1):"
curl -s "$PB_URL/api/collections/horses/records?filter=(assessment='$ID1')" -H "Authorization: $TOKEN" \
  | python3 -c 'import sys, json; d = json.load(sys.stdin); print(d["totalItems"]); sys.exit(0 if d["totalItems"] == 1 else 1)'

echo "-- bad payload (expect 400):"
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$PB_URL/api/equine/sync-assessment" \
  -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d '{"horses": []}'

echo "-- cleanup:"
curl -s -o /dev/null -w "%{http_code}\n" -X DELETE \
  "$PB_URL/api/collections/assessments/records/$ID1" -H "Authorization: $TOKEN"
echo "ALL PASS"
