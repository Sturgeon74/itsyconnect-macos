#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

STANDALONE_DIR=".next/standalone"
SQLITE_REL="node_modules/better-sqlite3/build/Release/better_sqlite3.node"
SQLITE_OUT="$STANDALONE_DIR/$SQLITE_REL"
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

copy_standalone_module_aliases() {
  local alias_dir="$STANDALONE_DIR/.next/node_modules"
  if [[ ! -d "$alias_dir" ]]; then
    return
  fi

  find "$alias_dir" -maxdepth 1 -mindepth 1 | while read -r alias_path; do
    local target package_name
    if [[ -L "$alias_path" ]]; then
      target="$(readlink "$alias_path")"
      package_name="${target##*/node_modules/}"
    elif [[ -f "$alias_path/package.json" ]]; then
      target="$alias_path/package.json"
      package_name="$(node -p "JSON.parse(require('node:fs').readFileSync(process.argv[1], 'utf8')).name" "$alias_path/package.json")"
    else
      echo "[prepare] Could not resolve standalone module alias $alias_path" >&2
      exit 1
    fi

    if [[ -z "$package_name" || "$package_name" == "$target" ]]; then
      echo "[prepare] Could not resolve standalone module alias $alias_path -> $target" >&2
      exit 1
    fi

    echo "[prepare] Copying standalone module alias $(basename "$alias_path") -> $package_name..."
    rm -rf "$alias_path"
    if [[ -d "$STANDALONE_DIR/node_modules/$package_name" ]]; then
      cp -R "$STANDALONE_DIR/node_modules/$package_name" "$alias_path"
    elif [[ -d "node_modules/$package_name" ]]; then
      cp -R "node_modules/$package_name" "$alias_path"
    else
      echo "[prepare] Could not find package for standalone module alias $package_name" >&2
      exit 1
    fi
  done
}

if [[ ! -f "$STANDALONE_DIR/server.js" ]]; then
  SERVER_PATH="$(find "$STANDALONE_DIR" -type f -name server.js | head -n 1)"

  if [[ -z "$SERVER_PATH" ]]; then
    echo "[prepare] Could not find Next.js standalone server.js in $STANDALONE_DIR" >&2
    exit 1
  fi

  GENERATED_DIR="$(dirname "$SERVER_PATH")"
  echo "[prepare] Flattening standalone output from $GENERATED_DIR..."
  cp -R "$GENERATED_DIR"/. "$STANDALONE_DIR"/

  RELATIVE_GENERATED_DIR="${GENERATED_DIR#"$STANDALONE_DIR"/}"
  TOP_LEVEL_GENERATED_DIR="${RELATIVE_GENERATED_DIR%%/*}"
  if [[ -n "$TOP_LEVEL_GENERATED_DIR" && "$TOP_LEVEL_GENERATED_DIR" != "$RELATIVE_GENERATED_DIR" ]]; then
    rm -rf "$STANDALONE_DIR/$TOP_LEVEL_GENERATED_DIR"
  fi
fi

echo "[prepare] Copying standalone assets..."
mkdir -p "$STANDALONE_DIR/.next"
rm -rf "$STANDALONE_DIR/public" "$STANDALONE_DIR/.next/static" "$STANDALONE_DIR/drizzle"
cp -r public "$STANDALONE_DIR/public"
cp -r .next/static "$STANDALONE_DIR/.next/static"
cp -r drizzle "$STANDALONE_DIR/drizzle"

ELECTRON_VERSION="$(node -e "const v=require('./package.json').devDependencies.electron; process.stdout.write(String(v).replace(/^[^0-9]*/, ''))")"
echo "[prepare] Building better-sqlite3 for Electron $ELECTRON_VERSION (arm64 + x64)..."

npx electron-rebuild -f --build-from-source --only better-sqlite3 --version "$ELECTRON_VERSION" --arch arm64
cp "node_modules/better-sqlite3/build/Release/better_sqlite3.node" "$TMP_DIR/better_sqlite3.arm64.node"

npx electron-rebuild -f --build-from-source --only better-sqlite3 --version "$ELECTRON_VERSION" --arch x64
cp "node_modules/better-sqlite3/build/Release/better_sqlite3.node" "$TMP_DIR/better_sqlite3.x64.node"

echo "[prepare] Creating universal better-sqlite3.node..."
mkdir -p "$(dirname "$SQLITE_OUT")"
lipo -create \
  "$TMP_DIR/better_sqlite3.arm64.node" \
  "$TMP_DIR/better_sqlite3.x64.node" \
  -output "$SQLITE_OUT"

echo "[prepare] Universal sqlite binary:"
file "$SQLITE_OUT"

copy_standalone_module_aliases

echo "[prepare] Restoring host-arch better-sqlite3 for local runtime..."
npm rebuild better-sqlite3

echo "[prepare] Done."
