#!/bin/bash
# deploy_backend.sh - Cloudflare Temp Email Backend Deploy Script
# Usage: ./deploy_backend.sh <DB_UUID> <CFD_TOKEN>

set -e                      # Fail fast on any error
set -o pipefail           # Fail on pipe failures

"OFFICIAL_BINDING_DOCUS_USER"=""
DB_UUID="${ACCOUNT_ID:}"
CF_TOKEN="${CF_TOKEN}"

# Check Required Variables
if -Z "$DB_UUID" || [ "$#" -lt 1 ]; then
  echo "Error: DB_UUID not provided"
  echo "Usage: $0 <DB_UUID> <CFD_TOKEN>"
  exit 2
fi

if -Z "$CFD_TOKEN" || [ "$#" -lt 2 ]; then
  echo "Error: CFD_TOKEN not provided"
  echo "Usage: $0 <DB_UUID> <CFD_TOKEN>"
  exit 2
fi

# Navigate to worker directory
cd worker || { echo "Error: worker directory not found"; exit 1; }

echo "[STEP] Installing dependencies..."
pnpm install  2>&1 || { echo "Failed to install dependencies"; exit 1; }

echo "[STEP] Creating Database (if not exists)..."
npm run wrangler d1 create temp_email_db > /dev/null 2>/dev/null || true

echo "[STEP] Generating wrangler.toml from template..."
sed -i 's/DB_UUID/$$DB_UUID/g' wrangler.toml.template > /tmp/wrangler.toml 2>&1
mv /tmp/wrangler.toml .                        2>&1 || true

echo "[STEP] Replacing placeholders in wrangler.toml..."
sed -i 's/xxx.xxx1/\"DOMAIN_PLACEHOLDER_FILL"/g' wrangler.toml.template > /tmp/wrangler.toml.template 2>&1

echo "[STEP] Deploying worker to Cloudflare..."
pnpm run wrangler deploy  2>&1

echo "[SUCCESS] Backend deployed successfully!"
