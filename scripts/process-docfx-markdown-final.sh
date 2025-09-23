#!/bin/bash

# Final enhanced script to process DocFX-generated markdown files for complete MDX 2 compatibility
# This version handles all the remaining edge cases and escaping issues

set -e

# Default directories
SOURCE_DIR="${1:-../cocos2d-mono/docfx/api}"
TARGET_DIR="${2:-../docs/api}"

echo "🔧 Processing DocFX markdown files for complete MDX 2 compatibility..."
echo "📁 Source: $SOURCE_DIR"
echo "📁 Target: $TARGET_DIR"

# Validate source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "❌ Error: Source directory '$SOURCE_DIR' does not exist!"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Function to comprehensively clean content for MDX
clean_for_mdx() {
    local content="$1"
    
    # Use multiple sed passes to handle complex escaping
    echo "$content" | \
        # Step 1: Remove HTML anchor tags and IDs completely
        sed 's/<a id="[^"]*"><\/a>//g' | \
        sed 's/<a id="[^"]*">//g' | \
        sed 's/<\/a>//g' | \
        \
        # Step 2: Fix all types of escaped characters
        sed 's/\\(/(/g' | \
        sed 's/\\)/)/g' | \
        sed 's/\\\\/\\/g' | \
        sed 's/\\`/`/g' | \
        sed 's/\\</</g' | \
        sed 's/\\>/>/g' | \
        sed 's/\\&/\&/g' | \
        sed 's/\\\?/?/g' | \
        sed 's/\\\[/[/g' | \
        sed 's/\\\]/]/g' | \
        \
        # Step 3: Clean up HTML entities
        sed 's/&lt;/</g' | \
        sed 's/&gt;/>/g' | \
        sed 's/&amp;/\&/g' | \
        sed 's/&quot;/"/g' | \
        sed 's/&#39;/'"'"'/g' | \
        \
        # Step 4: Remove or fix problematic HTML tags
        sed 's/<\/\?strong>/\*\*/g' | \
        sed 's/<\/\?em>/\*/g' | \
        sed 's/<\/\?code>/`/g' | \
        \
        # Step 5: Fix generic type syntax that causes MDX issues
        sed 's/<T>/&lt;T&gt;/g' | \
        sed 's/<\([A-Za-z][A-Za-z0-9]*\)>/\&lt;\1\&gt;/g' | \
        \
        # Step 6: Escape problematic characters in links
        sed 's/\[\([^]]*\)\\\([^]]*\)\]/[\1\2]/g' | \
        \
        # Step 7: Fix namespace/generic patterns that cause issues
        sed 's/\\<\([^>]*\)\\>/&lt;\1&gt;/g' | \
        \
        # Step 8: Remove duplicate sections (basic deduplication)
        awk '!seen[$0] || /^#/ || /^```/ {seen[$0]++; print}' | \
        \
        # Step 9: Clean up headings with HTML artifacts
        sed 's/^#\+\s*<[^>]*>\s*/# /' | \
        sed 's/^#\+\s*\([^<]*\)<[^>]*>\s*\(.*\)$/# \1\2/' | \
        \
        # Step 10: Fix problematic markdown constructs
        sed 's/^####\s*Parameters$/#### Parameters/' | \
        sed 's/^####\s*Returns$/#### Returns/' | \
        \
        # Step 11: Clean up excessive whitespace and empty lines
        sed 's/[[:space:]]*$//' | \
        awk '/^$/ {empty++; if (empty<=1) print} !/^$/ {empty=0; print}' | \
        \
        # Step 12: Remove lines that are just whitespace
        sed '/^[[:space:]]*$/d'
}

# Function to extract a clean title
extract_title() {
    local content="$1"
    local filename="$2"
    
    # Try multiple strategies to get a clean title
    local title=$(echo "$content" | \
        grep -m 1 '^# ' | \
        head -1 | \
        sed 's/^# //' | \
        sed 's/<[^>]*>//g' | \
        sed 's/\\//g' | \
        sed 's/&[^;]*;//g' | \
        tr -d '\r\n' | \
        sed 's/^[[:space:]]*//' | \
        sed 's/[[:space:]]*$//')
    
    # If no title found or it's problematic, derive from filename
    if [[ -z "$title" || "$title" == "# " || "$title" =~ ^\s*$ ]]; then
        title=$(echo "$filename" | \
            sed 's/\.md$//' | \
            sed 's/\./ /g' | \
            sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g' | \
            sed 's/-/ /g')
    fi
    
    # Final title cleanup
    title=$(echo "$title" | \
        sed 's/^Struct //' | \
        sed 's/^Class //' | \
        sed 's/^Interface //' | \
        sed 's/^Enum //' | \
        sed 's/^Namespace //' | \
        sed 's/\s\+/ /g' | \
        sed 's/^[[:space:]]*//' | \
        sed 's/[[:space:]]*$//')
    
    echo "$title"
}

# Function to generate a clean ID
generate_id() {
    local filename="$1"
    echo "$filename" | \
        sed 's/\.md$//' | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-zA-Z0-9._-]/-/g' | \
        sed 's/--*/-/g' | \
        sed 's/^-\|-$//g'
}

# Function to validate and fix frontmatter values
sanitize_frontmatter_value() {
    local value="$1"
    echo "$value" | \
        sed 's/"/\\"/g' | \
        sed 's/\s\+/ /g' | \
        sed 's/^[[:space:]]*//' | \
        sed 's/[[:space:]]*$//'
}

# Process counter
processed_count=0
skipped_count=0
error_count=0

echo "🔄 Processing files..."

# Process each markdown file
find "$SOURCE_DIR" -name "*.md" -type f | sort | while read -r file; do
    filename=$(basename "$file")
    target_file="$TARGET_DIR/$filename"
    
    echo "📄 Processing: $filename"
    
    # Read the original content
    if ! content=$(cat "$file" 2>/dev/null); then
        echo "  ⚠️  Warning: Could not read file $filename"
        ((skipped_count++))
        continue
    fi
    
    # Skip if file is empty or too small
    if [[ -z "$content" ]] || [[ ${#content} -lt 10 ]]; then
        echo "  ⏭️  Skipping empty/small file: $filename"
        ((skipped_count++))
        continue
    fi
    
    # Extract title and generate ID
    title=$(extract_title "$content" "$filename")
    id=$(generate_id "$filename")
    
    # Sanitize frontmatter values
    safe_title=$(sanitize_frontmatter_value "$title")
    safe_id=$(sanitize_frontmatter_value "$id")
    
    # Clean content for MDX
    processed_content=$(clean_for_mdx "$content")
    
    # Ensure we have some content after processing
    if [[ -z "$processed_content" ]] || [[ ${#processed_content} -lt 5 ]]; then
        echo "  ⚠️  Warning: Content became empty after processing, creating fallback for: $filename"
        processed_content="# $safe_title\n\nAPI documentation for $safe_title.\n\n> This page is currently being processed. Please check back later for complete documentation."
        ((error_count++))
    fi
    
    # Create the new file with proper frontmatter
    cat > "$target_file" << EOF
---
id: "$safe_id"
title: "$safe_title"
sidebar_label: "$safe_title"
hide_table_of_contents: false
---

$processed_content
EOF

    echo "  ✅ Created: $(basename "$target_file")"
    ((processed_count++))
done

echo ""
echo "📊 Processing Summary:"
echo "  ✅ Processed: $processed_count files"
echo "  ⏭️  Skipped: $skipped_count files"
echo "  ⚠️  Fallbacks created: $error_count files"

# Create an enhanced index file for the API docs
index_file="$TARGET_DIR/index.md"
cat > "$index_file" << 'EOF'
---
id: "api-index"
title: "API Reference"
sidebar_label: "API Reference"
hide_table_of_contents: false
---

# API Reference

Welcome to the Cocos2D Mono API Reference documentation. This comprehensive guide covers all classes, methods, and properties available in the Cocos2D Mono game engine.

## 🎮 About Cocos2D Mono

Cocos2D Mono is a C# implementation of the popular Cocos2D game engine, built on top of MonoGame. It provides a powerful yet simple framework for creating 2D games across multiple platforms.

## 📚 Documentation Structure

The API documentation is organized by namespaces:

### Core Namespaces

- **🎯 Cocos2D** - Main game engine functionality including scenes, sprites, actions, and audio
- **⚡ Box2D** - Integrated physics engine for realistic physics simulations

### 🧭 Navigation Tips

- Use the **sidebar** to browse through different classes and namespaces
- Use **Ctrl/Cmd + K** to quickly search for specific APIs
- Each class page includes constructors, properties, methods, and usage examples where available

## 🔧 Getting Started

If you're new to Cocos2D Mono, consider starting with these core classes:

- `CCScene` - Base class for game screens
- `CCSprite` - For displaying images and sprites  
- `CCLayer` - Container for game objects
- `CCAction` - For animations and transformations

## 📝 Note on Documentation

This API reference is automatically generated from the source code using DocFX. The documentation has been processed for compatibility with Docusaurus and MDX 2.

---

**Happy coding! 🚀**
EOF

echo "✅ Created enhanced API index: $index_file"

# Create a .gitignore for the processed files if it doesn't exist
gitignore_file="$TARGET_DIR/.gitignore"
if [[ ! -f "$gitignore_file" ]]; then
    cat > "$gitignore_file" << 'EOF'
# Auto-generated API documentation
# These files are generated from DocFX output and processed for MDX compatibility
*.md
!index.md
!_category_.json
EOF
    echo "✅ Created .gitignore: $gitignore_file"
fi

echo ""
echo "🎉 Complete! Your DocFX markdown files have been processed for full MDX 2 compatibility."
echo "📁 Processed files are available in: $TARGET_DIR"
echo ""
echo "🔄 Next steps:"
echo "  1. Run 'npm run build' or 'yarn build' to test the build"
echo "  2. Check the build output for any remaining issues"
echo "  3. Customize styling and components as needed"
echo ""
if [[ $error_count -gt 0 ]]; then
    echo "⚠️  Note: $error_count files required fallback content due to processing issues."
    echo "   These files may need manual review and enhancement."
    echo ""
fi
echo "💡 Tip: The processing has been designed to handle all known MDX 2 compatibility issues."