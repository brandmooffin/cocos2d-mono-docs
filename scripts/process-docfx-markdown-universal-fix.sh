#!/bin/bash

# Universal DocFX to MDX fix script
# This script handles ALL patterns that cause MDX compilation errors

echo "Starting universal DocFX to MDX compatibility processing..."

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
        
        # Apply all fixes using sed
        sed -E '
        # Fix any backtick + space + [type](link) pattern (parameters, field values, etc)
        s/(`[^`]*`) \[([^\]]+)\]\(([^)]+)\)/\1 \&amp;#91;\2\&amp;#93;(\3)/g
        
        # Fix space + [type](link) patterns anywhere in the file
        s/ \[([^\]]+)\]\(([^)]+)\)/ \&amp;#91;\1\&amp;#93;(\2)/g
        
        # Fix start of line [type](link) patterns
        s/^\[([^\]]+)\]\(([^)]+)\)/\&amp;#91;\1\&amp;#93;(\2)/g
        
        # Fix patterns with HTML entities that might be interpreted as JSX
        s/<([A-Za-z][^>]*[&<>][^>]*)>/\&amp;lt;\1\&amp;gt;/g
        
        # Fix generic type parameters with angle brackets
        s/<([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)*(?:<[^>]*>)?)>/\&amp;lt;\1\&amp;gt;/g
        
        # Fix inheritance patterns
        s/: \[([^\]]+)\]\(([^)]+)\)/: \&amp;#91;\1\&amp;#93;(\2)/g
        
        # Fix comma-separated type lists that look like JSX
        s/<([^>]*),([^>]*)>/\&amp;lt;\1,\2\&amp;gt;/g
        
        # Fix backslash escaped characters that might interfere
        s/\\([<>&])/\&amp;#92;\1/g
        
        # Fix question marks in type names
        s/<([^>]*)\?([^>]*)>/\&amp;lt;\1\&amp;#63;\2\&amp;gt;/g
        
        # Fix ampersand in type names
        s/<([^>]*)&([^>]*)>/\&amp;lt;\1\&amp;amp;\2\&amp;gt;/g
        
        # Fix square brackets in type names
        s/<([^>]*)\[([^>]*)\]([^>]*)>/\&amp;lt;\1\&amp;#91;\2\&amp;#93;\3\&amp;gt;/g
        ' "$file" > "$temp_file"
        
        # Replace the original file with the processed content
        mv "$temp_file" "$file"
        
        ((processed_count++))
    fi
done

echo "Universal processing completed! Processed $processed_count files."
echo "All known MDX compilation patterns have been addressed."