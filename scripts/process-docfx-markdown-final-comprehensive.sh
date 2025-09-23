#!/bin/bash

# FINAL comprehensive script to fix ALL remaining MDX compatibility issues
# This version specifically targets the problematic field value patterns

set -e

# Default directories
SOURCE_DIR="${1:-../cocos2d-mono/docfx/api}"
TARGET_DIR="${2:-../docs/api}"

echo "🎯 FINAL comprehensive DocFX to MDX conversion script..."
echo "📁 Source: $SOURCE_DIR"  
echo "📁 Target: $TARGET_DIR"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Function to handle the most comprehensive MDX cleaning
final_comprehensive_mdx_clean() {
    local content="$1"
    
    # Process in multiple very careful steps
    echo "$content" | \
        # Step 1: Remove HTML anchor tags completely
        sed 's/<a id="[^"]*"><\/a>//g' | \
        sed 's/<a id="[^"]*">//g' | \
        sed 's/<\/a>//g' | \
        \
        # Step 2: Fix escaped characters in ALL contexts FIRST
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
        sed 's/\\-/-/g' | \
        \
        # Step 3: Fix HTML entities
        sed 's/&lt;/</g' | \
        sed 's/&gt;/>/g' | \
        sed 's/&amp;/\&/g' | \
        sed 's/&quot;/"/g' | \
        sed 's/&#39;/'"'"'/g' | \
        \
        # Step 4: THE CRITICAL FIX - Handle field value patterns that cause MDX issues
        awk '
        BEGIN { 
            in_field_value = 0
            prev_line = ""
        }
        
        # Check if previous line was "#### Field Value" or similar
        /^#### Field Value/ { 
            in_field_value = 1
            print
            next
        }
        
        # If we are in a field value section and line starts with space + [type](link)
        in_field_value && /^ \[[^\]]+\]\([^)]+\)/ {
            # Convert to safe markdown
            gsub(/^ \[/, "**Type:** [")
            gsub(/\]/, "]**")
            print
            in_field_value = 0
            next
        }
        
        # Reset field value flag on new sections
        /^###/ || /^##/ || /^#/ {
            in_field_value = 0
        }
        
        # Handle inheritance lines that start with [type]
        /^\[.*\]\([^)]*\) ←$/ {
            gsub(/^\[/, "- **")
            gsub(/\]\([^)]*\)/, "**")
            gsub(/ ←$/, " (base class)")
            print
            next
        }
        
        # Handle member list items that end with comma
        /^\[.*\]\([^)]*\),$/ {
            gsub(/^\[/, "- **")
            gsub(/\]\([^)]*\)/, "**")
            gsub(/,$/, "")
            print
            next
        }
        
        # Handle problematic generic syntax in parameter lines
        /^`[^`]*`.*<\[.*\]>/ {
            gsub(/<\[/, "\\&lt;[")
            gsub(/\]>/, "]\\&gt;")
            print
            next
        }
        
        # Handle inheritance chains
        /^\[.*\]\([^)]*\) ←/ {
            gsub(/^\[/, "**")
            gsub(/\]\([^)]*\)/, "**")
            gsub(/ ←/, " ← ")
            print
            next
        }
        
        # Handle delegate or event handler patterns that include commas
        /Action<.*,.*>/ || /Func<.*,.*>/ {
            gsub(/</, "\\&lt;")
            gsub(/>/, "\\&gt;")
            print
            next
        }
        
        # Default: print the line as-is
        { 
            print
            prev_line = $0
        }
        ' | \
        \
        # Step 5: Fix remaining generic type patterns
        sed 's/<T>/\\&lt;T\\&gt;/g' | \
        sed 's/<\([A-Za-z][A-Za-z0-9]*\)>/\\&lt;\1\\&gt;/g' | \
        \
        # Step 6: Fix problematic tags that weren't caught
        sed 's/<\([^>]*[\\,&?[\]]\+[^>]*\)>/`\1`/g' | \
        \
        # Step 7: Convert remaining problematic inherited member patterns
        awk '
        BEGIN { in_members = 0 }
        /^## / { in_members = 0 }
        /^### / { in_members = 0 }
        /^#### Inherited Members/ { in_members = 1; print; next }
        in_members && /^\[.*\]\([^)]*\),$/ {
            gsub(/^\[/, "- ")
            print
            next
        }
        in_members && /^\[.*\]\([^)]*\)$/ {
            gsub(/^\[/, "- ")
            print
            next
        }
        { print }
        ' | \
        \
        # Step 8: Remove or fix remaining problematic HTML tags
        sed 's/<\/\?strong>/\*\*/g' | \
        sed 's/<\/\?em>/\*/g' | \
        sed 's/<\/\?code>/`/g' | \
        \
        # Step 9: Clean up headings
        sed 's/^#\+\s*<[^>]*>\s*/# /' | \
        sed 's/^#\+\s*\([^<]*\)<[^>]*>\s*\(.*\)$/# \1\2/' | \
        \
        # Step 10: Fix markdown constructs
        sed 's/^####\s*Parameters$/#### Parameters/' | \
        sed 's/^####\s*Returns$/#### Returns/' | \
        \
        # Step 11: Final cleanup
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
    processed_content=$(final_comprehensive_mdx_clean "$content")
    
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

# Create the API index (same as before)
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
echo "🎉 FINAL conversion complete with field value pattern fixes!"
echo "📁 Files available in: $TARGET_DIR"
echo ""
echo "🔥 This version specifically handles:"
echo "   ✅ Field Value patterns like ' [object](link)'"
echo "   ✅ Generic type syntax with commas"
echo "   ✅ Delegate and event handler patterns"
echo "   ✅ All previous fixes"
echo ""
echo "💡 Ready for: npm run build"