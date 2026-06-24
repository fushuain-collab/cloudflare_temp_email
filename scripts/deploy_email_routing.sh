#!/bin/bash
set -e
echo "=== Cloudflare Temp Email - Email Routing & Config Deploy ==="
echo "[1/7] Get Zone IDs"
ZONE_ASIA=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=nfs.asia" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['id'] if d.get('result') else '')")
ZONE_KDNS=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=nfs.kdns.fr" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['id'] if d.get('result') else '')")
echo "nfs.asia: $ZONE_ASIA | nfs.kdns.fr: $ZONE_KDNS"
echo "[2/7] Enable Email Routing"
for z in "$ZONE_ASIA" "$ZONE_KDNS"; do
  [ -z "$z" ] && continue
  curl -s -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$z/email/routing/enable" -d '{}' | python3 -c "import sys,json; print('  enabled:', json.load(sys.stdin).get('success'))"
done
echo "[3/7] Create Catch-All Rules to Worker"
WORKER_NAME="cloudflare_temp_email"
for z in "$ZONE_ASIA" "$ZONE_KDNS"; do
  [ -z "$z" ] && continue
  r=$(curl -s -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$z/email/routing/rules" -d '{"name":"Catch-All to Temp Mail Worker","enabled":true,"priority":0,"type":"catch_all","matchers":[{"type":"all"}],"actions":[{"type":"worker","value":[{"worker_name":"'"$WORKER_NAME"'"}]}]}')
  ok=$(echo "$r" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success',''))")
  if [ "$ok" != "True" ]; then
    list=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$z/email/routing/rules")
    rid=$(echo "$list" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(r['id']) for r in d.get('result',[]) if r.get('type')=='catch_all']")
    if [ -n "$rid" ]; then
      r=$(curl -s -X PUT -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$z/email/routing/rules/$rid" -d '{"name":"Catch-All to Temp Mail Worker","enabled":true,"priority":0,"type":"catch_all","matchers":[{"type":"all"}],"actions":[{"type":"worker","value":[{"worker_name":"'"$WORKER_NAME"'"}]}]}')
      echo "  updated: $(echo "$r" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success'))")"
    else
      echo "  error: $(echo "$r" | python3 -c "import sys,json; print(json.load(sys.stdin).get('errors'))")"
    fi
  else
    echo "  created: ok"
  fi
done
echo "[4/7] Set Frontend VITE_API_BASE"
pages=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects")
fname=$(echo "$pages" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(p['name']) for p in d.get('result',[]) if 'temp-email' in p['name'].lower() or 'temp_email' in p['name'].lower()]")
if [ -n "$fname" ]; then
  echo "  Project: $fname"
  curl -s -X PATCH -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$fname" -d '{"deployment_configs":{"production":{"env_vars":{"VITE_API_BASE":{"value":"https://cloudflare_temp_email.fushuain.workers.dev"}}},"preview":{"env_vars":{"VITE_API_BASE":{"value":"https://cloudflare_temp_email.fushuain.workers.dev"}}}}}' | python3 -c "import sys,json; print('  VITE_API_BASE set:', json.load(sys.stdin).get('success'))"
else
  echo "  Could not find project"
fi
echo "[5/7] Set FRONTEND_URL in Worker"
if [ -n "$fname" ]; then
  url=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$fname/deployments" | python3 -c "import sys,json; d=json.load(sys.stdin); [print('https://'+dep.get('url','')) for dep in d.get('result',[])]; exit()")
  [ -n "$url" ] && echo "  Frontend URL: $url" && curl -s -X PUT -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/services/cloudflare_temp_email/environments/production/variables" -d '{"vars":{"FRONTEND_URL":"'"$url"'"}}' && echo "  FRONTEND_URL set" || echo "  Could not get URL"
fi
echo "[6/7] Verify"
for z in "$ZONE_ASIA" "$ZONE_KDNS"; do
  [ -z "$z" ] && continue
  s=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$z/email/routing" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',{}).get('enabled','unknown'))")
  echo "  Zone $z: Email Routing enabled=$s"
done
echo "=== Complete! ==="
