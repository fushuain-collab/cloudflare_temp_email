#!/bin/bash
# Not using set -e to allow continuing even if some steps fail
echo "=== Cloudflare Temp Email - Email Routing & Config Deploy ==="

echo "[1/7] Get Zone IDs"
ZONE_ASIA=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=nfs.asia" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['id'] if d.get('result') else '') 2>/dev/null)
ZONE_KDNS=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=nfs.kdns.fr" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['id'] if d.get('result') else '') 2>/dev/null)
echo "nfs.asia: $ZONE_ASIA | nfs.kdns.fr: $ZONE_KDNS"

echo "[2/7] Enable Email Routing (try)"
for z in "$ZONE_ASIA" "$ZONE_KDNS"; do
  [ -z "$z" ] && continue
  curl -s -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$z/email/routing/enable" -d '{}' >/dev/null 2>&1 || echo "  Zone $z: Email Routing attempt failed (permission issue?)\n" || true
done

echo "[3/7] Create Catch-All Rules (try)"
for z in "$ZONE_ASIA" "$ZONE_KDNS"; do
  [ -z "$z" ] && continue
  curl -s -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$z/email/routing/rules" -d '{"name":"Catch-All","enabled":true,"priority":0,"type":"catch_all","matchers":[{"type":"all"}],"actions":[{"type":"worker","value":[{"worker_name":"cloudflare_temp_email"}]}]}' >/dev/null 2>&1 || echo "  Zone $z: Catch-All creation failed (permission issue?)" || true
done

echo "[4/7] Set Frontend VITE_API_BASE"
pages=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects")
fname=$(echo "$pages" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(p['name']) for p in d.get('result',[]) if 'temp-email' in p['name'].lower() or 'temp_email' in p['name'].lower()]" 2>/dev/null)
if [ -n "$fname" ]; then
  echo "  Project: $fname"
  curl -s -X PATCH -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$fname" -d '{"deployment_configs":{"production":{"env_vars":{"VITE_API_BASE":{"value":"https://cloudflare_temp_email.fushuain.workers.dev"}}},"preview":{"env_vars":{"VITE_API_BASE":{"value":"https://cloudflare_temp_email.fushuain.workers.dev"}}}}}' | python3 -c "import sys,json; print('  VITE_API_BASE set:', json.load(sys.stdin).get('success'))" 2>/dev/null
else
  echo "  skip: no project found"
fi

echo "[5/7] Set FRONTEND_URL in Worker"
if [ -n "$fname" ]; then
  deploys=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$fname/deployments")
  url=$(echo "$deploys" | python3 -c "import sys,json; d=json.load(sys.stdin); rs=d.get('result',[]); [print('https://'+dep.get('url,'')) for dep in rs if dep.get('url')]" 2>/dev/null | head -1)
  if [ -n "$url" ]; then
    echo "  Frontend URL: $url"
    curl -s -X PUT ".Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/services/cloudflare_temp_email/environments/production/variables" -d '{"vars":{"FRONTEND_URL":"'url'"}}' >/dev/null 2>&1 && echo "  FRONTEND_URL set" || echo "  Could not get URL"
  fi
fi

echo "[6/7] Verify"
for z in "$ZONE_ASIA" "$ZONE_KDNS"; do
  [ -z "$z" ] && continue
  s=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$z/email/routing" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('enabled','unknown')) 2>/dev/null")
  echo "  Zone $z: Email Routing enabled=$s"
done
echo "=== Complete! ==="
