#!/bin/bash

# Targeted DocFX to MDX fix script
# This script targets the specific patterns causing build failures

echo "Starting targeted MDX fix..."

# Directory containing markdown files
docs_dir="docs/api"

# Check if the directory exists
if [ ! -d "$docs_dir" ]; then
    echo "Error: Directory $docs_dir does not exist"
    exit 1
fi

processed_count=0

# Process all .md files in the docs/api directory recursively
find "$docs_dir" -name "*.md" -type f | while read -r file; do
    if [[ "$(basename "$file")" != "introduction.md" ]]; then
        echo "Processing: $file"
        
        # Create a temporary file
        temp_file=$(mktemp)
        
        # Apply targeted fixes
        sed '
        # Fix the specific pattern causing issues: backtick + content + backtick + space + [type](link)
        s/`\([^`]*\)` \[\([^]]*\)\](\([^)]*\))/`\1` \&amp;#91;\2\&amp;#93;(\3)/g
        
        # Fix space + [type](link) patterns
        s/ \[\([^]]*\)\](\([^)]*\))/ \&amp;#91;\1\&amp;#93;(\2)/g
        
        # Fix line start [type](link) patterns
        s/^\[\([^]]*\)\](\([^)]*\))/\&amp;#91;\1\&amp;#93;(\2)/g
        
        # Fix inheritance patterns ": [type](link)"
        s/: \[\([^]]*\)\](\([^)]*\))/: \&amp;#91;\1\&amp;#93;(\2)/g
        
        # Fix angle brackets containing special characters
        s/<\([^>]*[&<>?\\,\[\]][^>]*\)>/\&amp;lt;\1\&amp;gt;/g
        ' "$file" > "$temp_file"
        
        # Replace the original file with the processed content
        mv "$temp_file" "$file"
        
        ((processed_count++))
    fi
done

echo "Targeted processing completed! Processed $processed_count files."