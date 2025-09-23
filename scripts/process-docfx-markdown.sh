#!/bin/bash

# Script to process DocFX-generated markdown files for MDX 2 and Docusaurus compatibility
# Usage: ./process-docfx-markdown.sh [source_dir] [target_dir]

set -e

# Default directories
SOURCE_DIR="${1:-../cocos2d-mono/docfx/api}"
TARGET_DIR="${2:-../docs/api}"

echo "Processing DocFX markdown files..."
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Process each markdown file
find "$SOURCE_DIR" -name "*.md" -type f | while read -r file; do
    filename=$(basename "$file")
    target_file="$TARGET_DIR/$filename"
    
    echo "Processing: $filename"
    
    # Read the original content
    content=$(cat "$file")
    
    # Skip if file is empty
    if [[ -z "$content" ]]; then
        echo "  Skipping empty file: $filename"
        continue
    fi
    
    # Extract title from the first heading
    title=$(echo "$content" | grep -m 1 '^# ' | sed 's/^# //' | sed 's/<[^>]*>//g' | sed 's/\\//g' | tr -d '\r\n')
    
    # If no title found, use filename
    if [[ -z "$title" ]]; then
        title=$(echo "$filename" | sed 's/\.md$//' | sed 's/\./ /g')
    fi
    
    # Generate a clean ID from the filename
    id=$(echo "$filename" | sed 's/\.md$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    
    # Process the content
    processed_content=$(echo "$content" | \
        # Remove HTML anchor tags with IDs
        sed 's/<a id="[^"]*"><\/a>//g' | \
        sed 's/<a id="[^"]*">//g' | \
        sed 's/<\/a>//g' | \
        # Fix escaped parentheses in links
        sed 's/\\(/(/g' | \
        sed 's/\\)/)/g' | \
        # Fix escaped backslashes
        sed 's/\\\\/\\/g' | \
        # Remove or fix problematic HTML tags
        sed 's/<\/\?strong>//g' | \
        sed 's/<\/\?em>//g' | \
        # Clean up extra whitespace
        sed 's/  */ /g' | \
        # Remove empty lines at the start
        sed '/./,$!d' | \
        # Fix heading with HTML tags
        sed 's/^# <[^>]*> \(.*\)$/# \1/' | \
        # Remove duplicate constructors/methods (basic deduplication)
        awk '!seen[$0]++' | \
        # Remove lines that are just whitespace
        sed '/^[[:space:]]*$/d'
    )
    
    # Create the new file with frontmatter
    cat > "$target_file" << EOF
---
id: "$id"
title: "$title"
sidebar_label: "$title"
hide_table_of_contents: false
---

$processed_content
EOF

    echo "  ✓ Created: $target_file"
done

echo ""
echo "Processing completed!"
echo "Generated files are in: $TARGET_DIR"

# Create an index file for the API docs
index_file="$TARGET_DIR/index.md"
cat > "$index_file" << 'EOF'
---
id: "api-index"
title: "API Reference"
sidebar_label: "API Reference"
hide_table_of_contents: false
---

# API Reference

This section contains the complete API reference for Cocos2D Mono, automatically generated from the source code documentation.

## Namespaces

The API is organized into the following main namespaces:

- **Box2D** - Physics engine components
- **Cocos2D** - Core game engine functionality

## Navigation

Use the sidebar to navigate through the different classes, methods, and properties available in the API.

> **Note:** This documentation is automatically generated from DocFX output and may contain formatting inconsistencies. We're continuously working to improve the documentation quality.
EOF

echo "✓ Created API index: $index_file"

# Make the script executable
chmod +x "$0"

echo ""
echo "All done! You can now build your Docusaurus site with the processed API documentation."