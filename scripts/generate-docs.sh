#!/bin/bash

echo "Preparing SDK sources"

# Remove old docs and staged code
rm -rf docs
rm -rf src

# Reuse an existing extracted SDK tree, or extract the archive when available.
if [ ! -d tmp/code/types/mod ] || [ ! -f tmp/code/modlib/index.ts ]; then
  unzip -q PortalSDK.zip -d tmp
fi

# Create src directory if it doesn't exist
mkdir -p src

# Move the required files to src folder
cp tmp/code/types/mod/index.d.ts src/sdk.d.ts
cp tmp/code/modlib/index.ts src/modlib.ts

# Add triple-slash reference directive to modlib.ts if not already present
sed -i '1s/^/\/\/\/ <reference path=".\/sdk.d.ts" \/>\n\n/' src/modlib.ts

# Clean up temporary directory
rm -rf tmp

# Generate documentation using typedoc
npx typedoc --name "Unofficial BF6 Portal SDK Docs" --readme README.md --entryPointStrategy Expand src
