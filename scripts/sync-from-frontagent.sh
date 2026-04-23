#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="${FRONTAGENT_OUTPUT_DIR:-/Users/sangmin/Desktop/Claude/Projects/frontagent/output}"
TARGET_DIR="$PROJECT_ROOT/public"

echo "Syncing content from frontagent/output to public/..."

# Validate source directory
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory not found: $SOURCE_DIR"
  echo "Please ensure frontagent has generated output files first."
  exit 1
fi

# Create public directory if not exists
mkdir -p "$TARGET_DIR"

# Sync all files (HTML, CSS, JS, images)
echo "Syncing files..."
rsync -av --delete "$SOURCE_DIR/" "$TARGET_DIR/"

echo ""
echo "Sync completed!"
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo ""
echo "Files synced:"
ls -lh "$TARGET_DIR" | head -20
echo ""
echo "Next steps:"
echo "1. Verify public/ directory contents: ls -la public/"
echo "2. Commit changes: git add public/ && git commit -m 'Update static site'"
echo "3. Push to GitHub: git push origin main"
echo "4. Amplify will automatically deploy the updated site"
echo ""
