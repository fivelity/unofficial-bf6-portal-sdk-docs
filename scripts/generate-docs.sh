#!/bin/bash

echo "Extracting PortalSDK.zip"

# Remove old docs and code
rm -rf docs
rm -rf src

# Extract PortalSDK.zip to tmp directory
unzip -q PortalSDK.zip -d tmp

# Create src directory if it doesn't exist
mkdir -p src

# Move the required files to src folder
mv tmp/code/types/mod/index.d.ts src/sdk.d.ts
mv tmp/code/modlib/index.ts src/modlib.ts

# Add triple-slash reference directive to modlib.ts if not already present
sed -i '1s/^/\/\/\/ <reference path=".\/sdk.d.ts" \/>\n\n/' src/modlib.ts

# Clean up temporary directory
rm -rf tmp

# Generate documentation using typedoc
npx typedoc --name "BF6 Portal SDK 1.4.3.0" --readme README.md --entryPointStrategy Expand src
