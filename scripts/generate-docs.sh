#!/bin/bash

set -euo pipefail

echo "Preparing SDK sources from src"

# src contains the SDK source of truth; only remove generated output.
rm -rf docs

# Keep a compatibility fallback for archive-only checkouts.
if [ ! -f src/sdk.d.ts ] || [ ! -f src/modlib.ts ]; then
  if [ ! -d tmp/code/types/mod ] || [ ! -f tmp/code/modlib/index.ts ]; then
    unzip -q PortalSDK.zip -d tmp
  fi
  mkdir -p src
  cp tmp/code/types/mod/index.d.ts src/sdk.d.ts
  cp tmp/code/modlib/index.ts src/modlib.ts
fi

if ! grep -qF '/// <reference path="./sdk.d.ts" />' src/modlib.ts; then
  sed -i '1s/^/\/\/\/ <reference path=".\/sdk.d.ts" \/>\n\n/' src/modlib.ts
fi

npx typedoc --options typedoc.json
