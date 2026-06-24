#!/bin/bash
# deploy_frontend.sh - Cloudflare Temp Email Frontend Deploy Script
# This script is run from the repo root (after checkout).

set -e

echo "=== Cloudflare Temp Email Frontend Deploy ==="

echo "[1/6] Build frontend with Pages mode"
cd frontend || { echo "ERROR: frontend directory not found"; exit 1; }

echo "$FRONTEND_ENV" > .env.prod
pnpm install --no-frozen-lockfile 2>&1 || { echo "ERROR: pnpm install failed"; exit 1; }
pnpm run build:pages 2>&1 || { echo "ERROR: frontend build failed"; exit 1; }

echo "[2/6] Frontend build complete, checking dist/"
if [ ! -d "dist" ]; then
  echo "ERROR: dist/ not found after build"
  exit 1
fi
ls -la dist/

echo "[3/6] Setup pages directory"
cd ../pages || { echo "ERROR: pages directory not found"; exit 1; }
pnpm install --no-frozen-lockfile 2>&1 || { echo "ERROR: pages pnpm install failed"; exit 1; }

echo "[4/6] Create Pages project if not exists"
if [ -n "$FRONTEND_NAME" ]; then
  npx wrangler pages project create "$FRONTEND_NAME" --production-branch main 2>&1 || echo "Project may already exist, continuing..."
fi

echo "[5/6] Deploy frontend to Cloudflare Pages"
if [ -n "$FRONTEND_NAME" ]; then
  echo "Deploying to Pages project: $FRONTEND_NAME"
  npx wrangler pages deploy ../frontend/dist --project-name="$FRONTEND_NAME" --branch production 2>&1
else
  echo "Deploying to default Pages project"
  npx wrangler pages deploy ../frontend/dist --branch production 2>&1
fi

echo "[6/6] Deploy pages functions (if any)"
npx wrangler pages functions build --outfile=./functions/worker.js 2>&1 || true

echo "=== Frontend deploy complete! ==="
