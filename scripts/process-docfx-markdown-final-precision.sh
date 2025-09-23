#!/bin/bash

# FINAL comprehensive script to fix ALL DocFX markdown files for MDX 2 compatibility
# This version handles the exact patterns that are still causing errors

echo "🔧 Starting FINAL comprehensive DocFX markdown processing..."
echo "📁 Processing files from: ../docs/api"

# Create output directory
mkdir -p ../docs/api

# Function to process files with final comprehensive MDX fixes
final_comprehensive_mdx_clean() {
    local input_file="$1"
    
    # Use sed to handle the exact patterns that are failing
    sed -i '' -e '
        # Handle Field Value patterns - convert space + [type](link) to **Type:** [type](link)
        /^#### Field Value$/,/^###/ {
            s/^ \[\([^]]*\)\](\([^)]*\))/**Type:** [\1](\2)/g
        }
        
        # Handle Parameter patterns - convert `param` [Type](link) to `param` **Type:** [Type](link)
        /^#### Parameters$/,/^###/ {
            s/^\(`[^`]*`\) \[\([^]]*\)\](\([^)]*\))/\1 **Type:** [\2](\3)/g
        }
        
        # Handle any remaining space + [type](link) patterns globally
        s/^ \[\([^]]*\)\](\([^)]*\))/&ast;&ast;Type:&ast;&ast; [\1](\2)/g
        
        # Handle generic type patterns with angle brackets
        s/\[\([^]]*\)\](\([^)]*\))<\[\([^]]*\)\](\([^)]*\))>/[\1](\2)&lt;[\3](\4)&gt;/g
        
        # Escape any remaining problematic patterns
        s/<\([^<>]*\),\([^<>]*\)>/\&lt;\1,\2\&gt;/g
        s/\[\]/\&lbrack;\&rbrack;/g
        
        # Handle HTML entities that might be in inheritance sections
        s/Action&lt;\([^&]*\)&gt;/Action\&lt;\1\&gt;/g
        s/Func&lt;\([^&]*\)&gt;/Func\&lt;\1\&gt;/g
        s/EventHandler&lt;\([^&]*\)&gt;/EventHandler\&lt;\1\&gt;/g
        
    ' "$input_file"
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
        
        # Apply final comprehensive MDX cleaning
        final_comprehensive_mdx_clean "$file"
        
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
echo "🎉 FINAL conversion complete with precise pattern fixes!"
echo "📁 Files available in: ../docs/api"
echo ""
echo "🔥 This version handles:"
echo "   ✅ Field Value sections with precise space + [type](link) patterns"
echo "   ✅ Parameter sections with precise \`param\` [Type](link) patterns" 
echo "   ✅ Generic type syntax with angle bracket escaping"
echo "   ✅ Array bracket escaping"
echo "   ✅ HTML entity escaping for delegates"
echo ""
echo "💡 Ready for: npm run build"