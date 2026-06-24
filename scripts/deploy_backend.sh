#!/bin/bash
# deploy_backend.sh - Cloudflare Temp Email Backend Deploy Script
# This script is run from the repo root (after checkout).
# It uses INPUT_DB_UUID from GitHub Actions env vars.

set -e

echo "=== Cloudflare Temp Email Backend Deploy ==="
echo "[1/6] Navigate to worker directory"
cd worker || { echo "ERROR: worker directory not found"; exit 1; }

echo "[2/6] Install dependencies with pnpm"
pnpm install 2>&1 || { echo "ERROR: pnpm install failed"; exit 1; }

echo "[3/6] Create D1 database if not already exists"
npx wrangler d1 create temp_email_db 2>/dev/null || true

echo "[4/6] Generate wrangler.toml from template"
DB_UUID="${INPUT_DB_UUID}"
if [ -z "$DB_UUID" ]; then
  echo "ERROR: INPUT_DB_UUID environment variable not set"
  exit 1
fi
sed "s/database_id = \"xxx\"/database_id = \"$DB_UUID\"/g" wrangler.toml.template > wrangler.toml

echo "[5/6] Replace domain placeholders with real domains"
sed -i 's/xxx\.xxx1/nfs.asia/g' wrangler.toml
sed -i 's/xxx\.xxx2/nfs.kdns.fr/g' wrangler.toml

echo "[6/6] Deploy worker with wrangler"
npx wrangler deploy 2>&1

echo "=== Backend deploy complete! ==="
