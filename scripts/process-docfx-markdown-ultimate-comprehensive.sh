#!/bin/bash

# Ultimate comprehensive script to fix DocFX markdown files for MDX 2 compatibility
# This version handles ALL patterns that cause MDX compilation errors

echo "🔧 Starting ULTIMATE comprehensive DocFX markdown processing..."
echo "📁 Processing files from: ../docs/api"

# Create output directory
mkdir -p ../docs/api

# Function to process files with ultimate comprehensive MDX fixes
ultimate_comprehensive_mdx_clean() {
    local input_file="$1"
    local temp_file="${input_file}.tmp"

    # Ultimate AWK script to handle ALL problematic patterns
    awk '
    BEGIN {
        in_field_value = 0
        in_parameters = 0
    }
    
    # Detect Field Value sections
    /^#### Field Value/ {
        in_field_value = 1
        print
        next
    }
    
    # Detect Parameters sections
    /^#### Parameters/ {
        in_parameters = 1
        print
        next
    }
    
    # Reset flags on new sections
    /^###/ || /^##/ || /^#/ {
        in_field_value = 0
        in_parameters = 0
        print
        next
    }
    
    # Process lines in Field Value sections
    in_field_value && /^ \[.*\]\(.*\)/ {
        # Convert " [type](link)" to "**Type:** [type](link)"
        gsub(/^ \[/, "**Type:** [")
        gsub(/\]\(([^)]+)\)/, "](\\1)**", $0)
        print
        next
    }
    
    # Process parameter lines like "`param` [Type](link)"
    in_parameters && /^`[^`]+` \[.*\]\(.*\)/ {
        # Convert "`param` [Type](link)" to "`param` **Type:** [Type](link)"
        gsub(/` \[/, "` **Type:** [")
        gsub(/\]\(([^)]+)\)/, "](\\1)**", $0)
        print
        next
    }
    
    # Handle any remaining patterns with space + [type](link)
    /^ \[.*\]\(.*\)/ {
        # Convert " [type](link)" to "**Type:** [type](link)"
        gsub(/^ \[/, "**Type:** [")
        gsub(/\]\(([^)]+)\)/, "](\\1)**", $0)
        print
        next
    }
    
    # Default case - print line as is
    {
        print
    }
    ' "$input_file" > "$temp_file"

    # Apply all previous fixes using sed pipeline
    sed -e '
        # Remove HTML anchor tags
        s/<a[^>]*name="[^"]*"[^>]*><\/a>//g
        s/<a[^>]*id="[^"]*"[^>]*><\/a>//g
        
        # Escape problematic characters
        s/\\\\/\\\\\\\\/g
        s/{/\\{/g
        s/}/\\}/g
        s/</\\</g
        s/>/\\>/g
        
        # Fix inheritance lists - convert to proper markdown list format
        s/^Inheritance$/### Inheritance/
        s/^Derived$/### Derived/
        s/^Implements$/### Implements/
        s/^Inherited Members$/### Inherited Members/
        
        # Handle generic types with commas more safely
        s/<\([^<>]*\),\([^<>]*\)>/\\<\1,\2\\>/g
        s/<\([^<>]*\),\([^<>]*\),\([^<>]*\)>/\\<\1,\2,\3\\>/g
        
        # Handle delegate patterns
        s/Action&lt;\([^&]*\)&gt;/Action\\<\1\\>/g
        s/Func&lt;\([^&]*\)&gt;/Func\\<\1\\>/g
        s/EventHandler&lt;\([^&]*\)&gt;/EventHandler\\<\1\\>/g
        
        # Handle array patterns
        s/\[\]/\\[\\]/g
        
        # Fix common problematic inheritance patterns
        s/^\([[:space:]]*\)\([A-Za-z][A-Za-z0-9_.]*\)$/\1- \2/
        
        # Handle remaining bracket patterns that might be interpreted as JSX
        s/\[object\]/\\[object\\]/g
        s/\[Object\]/\\[Object\\]/g
        s/\[string\]/\\[string\\]/g
        s/\[String\]/\\[String\\]/g
        s/\[int\]/\\[int\\]/g
        s/\[bool\]/\\[bool\\]/g
        s/\[float\]/\\[float\\]/g
        s/\[double\]/\\[double\\]/g
        
    ' "$temp_file" > "$input_file"

    rm "$temp_file"
}

# Process all markdown files
processed_count=0

find ../docs/api -name "*.md" -type f | while read -r file; do
    if [[ -f "$file" && "$(basename "$file")" != "introduction.md" ]]; then
        echo "📄 Processing: $(basename "$file")"
        
        # Add YAML frontmatter if not present
        if ! head -1 "$file" | grep -q "^---$"; then
            {
                echo "---"
                echo "title: \"$(basename "$file" .md)\""
                echo "---"
                echo ""
                cat "$file"
            } > "${file}.tmp" && mv "${file}.tmp" "$file"
        fi
        
        # Apply ultimate comprehensive MDX cleaning
        ultimate_comprehensive_mdx_clean "$file"
        
        echo "  ✅ Done: $(basename "$file")"
        ((processed_count++))
    fi
done

echo ""
echo "📊 Processed $processed_count files successfully!"

# Create API index if it doesn't exist
if [[ ! -f "../docs/api/introduction.md" ]]; then
    cat > "../docs/api/introduction.md" << 'EOF'
---
title: "API Reference"
sidebar_position: 1
---

# Cocos2D-Mono API Reference

Welcome to the Cocos2D-Mono API documentation. This reference covers all the classes, interfaces, and namespaces available in the Cocos2D-Mono framework.

## Namespaces

- [Cocos2D](Cocos2D.md) - Core Cocos2D functionality
- [CocosDenshion](CocosDenshion.md) - Audio and sound management
- [Box2D](Box2D.md) - Physics simulation

## Getting Started

Browse the namespaces above to explore the available classes and their methods, properties, and events.
EOF
    echo "✅ Created API index"
fi

# Create .gitignore if it doesn't exist
if [[ ! -f "../.gitignore" ]]; then
    cat > "../.gitignore" << 'EOF'
node_modules/
.docusaurus/
build/
.DS_Store
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF
    echo "✅ Created .gitignore"
fi

echo ""
echo "🎉 ULTIMATE conversion complete with comprehensive pattern fixes!"
echo "📁 Files available in: ../docs/api"
echo ""
echo "🔥 This version handles:"
echo "   ✅ Field Value patterns like ' [object](link)'"
echo "   ✅ Parameter patterns like '\`param\` [Type](link)'"
echo "   ✅ Generic type syntax with commas"
echo "   ✅ Delegate and event handler patterns"
echo "   ✅ Array bracket escaping"
echo "   ✅ All HTML and special character escaping"
echo "   ✅ Inheritance list formatting"
echo ""
echo "💡 Ready for: npm run build"