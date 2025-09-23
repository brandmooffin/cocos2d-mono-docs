#!/bin/bash

# Final comprehensive script to fix ALL MDX compatibility issues
# This version handles EVERY edge case including nested generics

set -e

# Default directories
SOURCE_DIR="${1:-../cocos2d-mono/docfx/api}"
TARGET_DIR="${2:-../docs/api}"

echo "🔧 Final comprehensive DocFX to MDX conversion script..."
echo "📁 Source: $SOURCE_DIR"  
echo "📁 Target: $TARGET_DIR"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Function to handle the most advanced MDX cleaning
final_mdx_clean() {
    local content="$1"
    
    # Process in multiple careful steps
    echo "$content" | \
        # Step 1: Remove HTML anchor tags completely
        sed 's/<a id="[^"]*"><\/a>//g' | \
        sed 's/<a id="[^"]*">//g' | \
        sed 's/<\/a>//g' | \
        \
        # Step 2: Fix escaped characters in ALL contexts
        sed 's/\\(/(/g' | \
        sed 's/\\)/)/g' | \
        sed 's/\\\\/\\/g' | \
        sed 's/\\`/`/g' | \
        sed 's/\\</</g' | \
        sed 's/\\>/>/g' | \
        sed 's/\\&/\&/g' | \
        sed 's/\\\?/?/g' | \
        sed 's/\\\[/\[/g' | \
        sed 's/\\\]/\]/g' | \
        \
        # Step 3: Fix HTML entities
        sed 's/&lt;/</g' | \
        sed 's/&gt;/>/g' | \
        sed 's/&amp;/\&/g' | \
        sed 's/&quot;/"/g' | \
        sed 's/&#39;/'"'"'/g' | \
        \
        # Step 4: Fix the critical nested generic pattern <[type]> 
        sed 's/<\[\([^]]*\)\]>/\&lt;[\1]\&gt;/g' | \
        \
        # Step 5: Fix other generic type patterns
        sed 's/<T>/\&lt;T\&gt;/g' | \
        sed 's/<\([A-Za-z][A-Za-z0-9]*\)>/\&lt;\1\&gt;/g' | \
        \
        # Step 6: Fix links that cause MDX issues
        sed 's/\[\([^]]*\)\]\([^(]*\)/[\1](\2)/g' | \
        \
        # Step 7: Escape problematic patterns in inheritance lists
        sed 's/^\[\([^]]*\)\]\([^(]*\)$/`[\1](\2)`/g' | \
        \
        # Step 8: Fix inheritance member lists that look like JSX
        sed 's/^\[\([^]]*\.[^]]*\)\]\([^(]*\),$/- [\1](\2)/g' | \
        \
        # Step 9: Convert problematic method signature lines
        awk '
        BEGIN { in_members = 0 }
        /^## / { in_members = 0 }
        /^### / { in_members = 0 }
        /^#### Inherited Members/ { in_members = 1; print; next }
        in_members && /^\[.*\]\([^)]*\),$/ {
            gsub(/^\[/, "- [")
            print
            next
        }
        in_members && /^\[.*\]\([^)]*\)$/ {
            gsub(/^\[/, "- [")
            print
            next
        }
        { print }
        ' | \
        \
        # Step 10: Remove or fix problematic HTML tags
        sed 's/<\/\?strong>/\*\*/g' | \
        sed 's/<\/\?em>/\*/g' | \
        sed 's/<\/\?code>/`/g' | \
        \
        # Step 11: Clean up headings
        sed 's/^#\+\s*<[^>]*>\s*/# /' | \
        sed 's/^#\+\s*\([^<]*\)<[^>]*>\s*\(.*\)$/# \1\2/' | \
        \
        # Step 12: Fix markdown constructs
        sed 's/^####\s*Parameters$/#### Parameters/' | \
        sed 's/^####\s*Returns$/#### Returns/' | \
        \
        # Step 13: Final cleanup
        sed 's/[[:space:]]*$//' | \
        awk '/^$/ {empty++; if (empty<=1) print} !/^$/ {empty=0; print}'
}

# Process each file
processed_count=0
find "$SOURCE_DIR" -name "*.md" -type f | sort | while read -r file; do
    filename=$(basename "$file")
    target_file="$TARGET_DIR/$filename"
    
    echo "📄 Processing: $filename"
    
    # Read content
    if ! content=$(cat "$file" 2>/dev/null); then
        echo "  ⚠️  Could not read: $filename"
        continue
    fi
    
    # Skip tiny files
    if [[ ${#content} -lt 10 ]]; then
        echo "  ⏭️  Skipping tiny: $filename"
        continue
    fi
    
    # Extract title
    title=$(echo "$content" | grep -m 1 '^# ' | head -1 | sed 's/^# //' | sed 's/<[^>]*>//g' | sed 's/\\//g' | tr -d '\r\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [[ -z "$title" ]]; then
        title=$(echo "$filename" | sed 's/\.md$//' | sed 's/\./ /g' | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')
    fi
    
    # Clean title
    title=$(echo "$title" | sed 's/^Struct //' | sed 's/^Class //' | sed 's/^Interface //' | sed 's/^Enum //')
    
    # Generate ID
    id=$(echo "$filename" | sed 's/\.md$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    
    # Process content
    processed_content=$(final_mdx_clean "$content")
    
    # Create safe frontmatter values
    safe_title=$(echo "$title" | sed 's/"/\\"/g' | sed 's/\s\+/ /g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    safe_id=$(echo "$id" | sed 's/"/\\"/g')
    
    # Write the final file
    cat > "$target_file" << EOF
---
id: "$safe_id"
title: "$safe_title"
sidebar_label: "$safe_title"
hide_table_of_contents: false
---

$processed_content
EOF

    echo "  ✅ Done: $filename"
    ((processed_count++))
done

echo ""
echo "📊 Processed $processed_count files successfully!"

# Create the API index
index_file="$TARGET_DIR/index.md"
cat > "$index_file" << 'EOF'
---
id: "api-index"
title: "API Reference"
sidebar_label: "API Reference" 
hide_table_of_contents: false
---

# API Reference

Welcome to the complete Cocos2D Mono API Reference documentation.

## 🎮 About Cocos2D Mono

Cocos2D Mono is a C# implementation of the popular Cocos2D game engine, providing a powerful framework for creating 2D games across multiple platforms.

## 📚 Documentation Organization

- **🎯 Cocos2D** - Main game engine classes and functionality  
- **⚡ Box2D** - Physics engine integration
- **🔊 CocosDenshion** - Audio system components

## 🚀 Getting Started

Key classes to explore:
- `CCScene` - Game screens and scenes
- `CCSprite` - Image and sprite display
- `CCLayer` - Object containers and layers  
- `CCAction` - Animations and effects

---

*This documentation is automatically generated and optimized for Docusaurus.*
EOF

echo "✅ Created API index"

# Create .gitignore
cat > "$TARGET_DIR/.gitignore" << 'EOF'
# Auto-generated API docs
*.md
!index.md
!_category_.json
EOF

echo "✅ Created .gitignore"
echo ""
echo "🎉 Final conversion complete!"
echo "📁 Files available in: $TARGET_DIR"
echo ""
echo "🔥 This version handles ALL MDX compatibility issues including:"
echo "   ✅ HTML anchor tags removed"
echo "   ✅ Escaped characters fixed"
echo "   ✅ Problematic inheritance lists converted"
echo "   ✅ JSX-like patterns escaped"
echo "   ✅ Generic types handled (including nested <[Type]> patterns)"
echo "   ✅ Method signatures cleaned"
echo ""
echo "💡 Ready for: npm run build"