#!/bin/bash
# Simplified script: Set pages env vars and worker FRONTEND_URL
set -e
echo "=== Cloudflare Temp Email - Config Deploy ==="

echo "[1/2] Set Frontend VITE_API_BASE"
pages=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects")
fname=$(echo "$pages" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(p['name']) for p in d.get('result',[]) if 'temp-email' in p['name'].lower() or 'temp_email' in p['name'].lower()]" 2>/dev/null)
if [ -n "$fname" ]; then
  echo "  Project: $fname"
  resp=$(curl -s -X PATCH -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$fname" -d '{"deployment_configs":{"production":{"env_vars":{"VITE_API_BASE":{"value":"https://cloudflare_temp_email.fushuain.workers.dev"}}},"preview":{"env_vars":{"VITE_API_BASE":{"value":"https://cloudflare_temp_email.fushuain.workers.dev"}}}}}' 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "  VITE_API_BASE set successfully"
  else
    echo "  VITE_API_BASE set failed"
  fi
else
  echo "  skip: no project found"
fi

echo "[2/2] Set FRONTEND_URL in Worker"
if [ -n "$fname" ]; then
  deploys=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$fname/deployments")
  url=$(echo "$deploys" | python3 -c "import sys,json; d=json.load(sys.stdin); rs=d.get('result',[]); [print('https://'+dep.get('url','')) for dep in rs if dep.get('url')]" 2>/dev/null | head -1)
  if [ -n "$url" ]; then
    echo "  Frontend URL: $url"
    curl -s -X PUT ".Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/services/cloudflare_temp_email/environments/production/variables" -d "{\"vars\":{\"FRONTEND_URL\":\"$url\"}}" 2>/dev/null && echo "  FRONTEND_URL set" || echo "  FRONTEND_URL failed"
  fi
fi

echo "=== Complete! ==="
