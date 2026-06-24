#!/bin/bash
set -e
echo "=== Redeploy Worker: cloudflare_temp_email ==="

cd /home/runner/work/cloudflare_temp_email/cloudflare_temp_email/worker || { echo "Failed to cd"; exit 1; }

npm install 2>/dev/null || echo "npm install skipped"

cat > wrangler.toml << 'TOML'
name = "cloudflare_temp_email"
main = "src/worker.ts"
compatibility_date = "2025-04-01"
compatibility_flags = [ "nodejs_compat" ]
keep_vars = true

[[d1_databases]]
binding = "DB"
database_name = "temp_email_db"
database_id = "d15a8696-757c-49f1-a176-248bf781bf98"

[vars]
DEFAULT_DOMAINS = ["nfs.asia"]
DOMAINS = ["nfs.asia", "nfs.kdns.fr"]
JWT_SECRET = "2601faeb0efe7e0bfd4ad42b0afdab92b234454ff58ba6056045f54dc71a112e"
BLACK_LIST = ""
FRONTEND_URL = "https://56396a71.temp-email-frontend-bqw.pages.dev"
TOML

echo "=== wrangler.toml ==="
cat wrangler.toml

echo "=== Deploying... ==="
npx wrangler deploy

echo "=== Setting FRONTEND_URL via API as fallback... ==="
FRONTEND_URL="https://56396a71.temp-email-frontend-bqw.pages.dev"
curl -s -X PUT   -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"   -H "Content-Type: application/json"   "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/services/cloudflare_temp_email/environments/production/variables"   -d '{"vars":{"FRONTEND_URL":"https://56396a71.temp-email-frontend-bqw.pages.dev"}}'   && echo "FRONTEND_URL API set OK" || echo "FRONTEND_URL API set skipped"

echo "=== Worker redeploy complete! ==="