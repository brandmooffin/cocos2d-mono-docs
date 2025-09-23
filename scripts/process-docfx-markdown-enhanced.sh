#!/bin/bash

# Enhanced script to process DocFX-generated markdown files for MDX 2 and Docusaurus compatibility
# This version handles more complex MDX issues and provides better formatting

set -e

# Default directories
SOURCE_DIR="${1:-../cocos2d-mono/docfx/api}"
TARGET_DIR="${2:-../docs/api}"

echo "🚀 Processing DocFX markdown files for MDX 2 compatibility..."
echo "📁 Source: $SOURCE_DIR"
echo "📁 Target: $TARGET_DIR"

# Validate source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "❌ Error: Source directory '$SOURCE_DIR' does not exist!"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Function to clean and escape content for MDX
clean_for_mdx() {
    local content="$1"
    
    # Use sed to process the content step by step
    echo "$content" | \
        # Remove HTML anchor tags and IDs
        sed 's/<a id="[^"]*"><\/a>//g' | \
        sed 's/<a id="[^"]*">//g' | \
        sed 's/<\/a>//g' | \
        # Fix escaped characters in links and text
        sed 's/\\(/(/g' | \
        sed 's/\\)/)/g' | \
        sed 's/\\\\/\\/g' | \
        sed 's/\\`/`/g' | \
        # Clean up HTML tags that aren't supported in MDX
        sed 's/<\/\?strong>/\*\*/g' | \
        sed 's/<\/\?em>/\*/g' | \
        sed 's/<\/\?code>/`/g' | \
        # Fix problematic characters in code blocks
        sed 's/&lt;/</g' | \
        sed 's/&gt;/>/g' | \
        sed 's/&amp;/\&/g' | \
        sed 's/&quot;/"/g' | \
        # Remove or fix problematic markdown constructs
        sed 's/^####\s*Parameters$/#### Parameters/' | \
        sed 's/^####\s*Returns$/#### Returns/' | \
        # Clean up excessive whitespace
        sed 's/[[:space:]]*$//' | \
        sed '/^$/N;/^\n$/d' | \
        # Fix headings that contain HTML
        sed 's/^#\+\s*<[^>]*>\s*/# /' | \
        # Remove duplicate blank lines
        awk '!/^$/ {print; blanks=0} /^$/ {blanks++; if (blanks<=1) print}'
}

# Function to extract a clean title
extract_title() {
    local content="$1"
    local filename="$2"
    
    # Try to get title from first heading
    local title=$(echo "$content" | grep -m 1 '^# ' | head -1 | sed 's/^# //' | sed 's/<[^>]*>//g' | sed 's/\\//g' | tr -d '\r\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # If no title found, derive from filename
    if [[ -z "$title" || "$title" == "# " ]]; then
        title=$(echo "$filename" | sed 's/\.md$//' | sed 's/\./ /g' | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')
    fi
    
    # Clean the title further
    title=$(echo "$title" | sed 's/^Struct //' | sed 's/^Class //' | sed 's/^Interface //' | sed 's/^Enum //')
    
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

# Process counter
processed_count=0
skipped_count=0

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
    
    # Clean content for MDX
    processed_content=$(clean_for_mdx "$content")
    
    # Ensure we have some content after processing
    if [[ -z "$processed_content" ]] || [[ ${#processed_content} -lt 5 ]]; then
        echo "  ⚠️  Warning: Content became empty after processing: $filename"
        # Create minimal fallback content
        processed_content="# $title\n\nAPI documentation for $title."
    fi
    
    # Create the new file with proper frontmatter
    cat > "$target_file" << EOF
---
id: "$id"
title: "$title"
sidebar_label: "$title"
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

This API reference is automatically generated from the source code using DocFX. While we strive for accuracy, some formatting may be inconsistent. If you notice any issues, please report them on our GitHub repository.

---

**Happy coding! 🚀**
EOF

echo "✅ Created enhanced API index: $index_file"

# Create a .gitignore for the processed files if it doesn't exist
gitignore_file="$TARGET_DIR/.gitignore"
if [[ ! -f "$gitignore_file" ]]; then
    cat > "$gitignore_file" << 'EOF'
# Auto-generated API documentation
# These files are generated from DocFX output
*.md
!index.md
!_category_.json
EOF
    echo "✅ Created .gitignore: $gitignore_file"
fi

echo ""
echo "🎉 All done! Your DocFX markdown files have been processed for MDX 2 compatibility."
echo "📁 Processed files are available in: $TARGET_DIR"
echo ""
echo "🔄 Next steps:"
echo "  1. Build your Docusaurus site to test compatibility"
echo "  2. Check for any remaining build errors"
echo "  3. Customize the index.md file as needed"
echo ""
echo "💡 Tip: Run 'npm run build' or 'yarn build' in your Docusaurus project to test the processed documentation."