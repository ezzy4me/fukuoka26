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

# Create images directory
mkdir -p "$TARGET_DIR/images"

# Copy images from Ref directory
IMAGE_SOURCE="${FRONTAGENT_REF_DIR:-/Users/sangmin/Desktop/Claude/Projects/frontagent/Ref}"
if [ -d "$IMAGE_SOURCE" ]; then
  echo ""
  echo "Copying images from Ref directory..."
  # Copy image files with proper error handling
  for ext in png jpg jpeg gif svg; do
    if ls "$IMAGE_SOURCE"/*.$ext 1> /dev/null 2>&1; then
      cp "$IMAGE_SOURCE"/*.$ext "$TARGET_DIR/images/" 2>/dev/null || true
    fi
  done
  echo "✓ Images copied to public/images/"
else
  echo "Warning: Image source directory not found: $IMAGE_SOURCE"
fi

# Fix image paths in HTML files (../Ref/ → /images/)
echo ""
echo "Fixing image paths in HTML files..."
find "$TARGET_DIR" -name "*.html" -type f ! -name "*.bak*" ! -name "*.backup" -exec sed -i '' 's|../Ref/|/images/|g' {} \;
echo "✓ Image paths fixed (../Ref/ → /images/)"

# Verify images
echo ""
echo "Verifying copied images:"
if [ -d "$TARGET_DIR/images" ]; then
  ls -lh "$TARGET_DIR/images" | grep -E '\.(png|jpg|jpeg|gif|svg)$' || echo "No image files found"
else
  echo "Warning: images/ directory not created"
fi

echo ""
echo "==========================================="
echo "Sync completed!"
echo "==========================================="
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo ""
echo "Files synced:"
ls -lh "$TARGET_DIR" | head -20
echo ""
echo "Next steps:"
echo "1. Verify public/ directory contents: ls -la public/"
echo "2. Check image paths fixed: grep -r '../Ref/' public/*.html (should be empty)"
echo "3. Commit changes: git add public/ && git commit -m 'Update static site'"
echo "4. Push to GitHub: git push origin main"
echo "5. Amplify will automatically deploy the updated site"
echo ""
