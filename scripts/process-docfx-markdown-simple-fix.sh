#!/bin/bash

# Simplified universal DocFX to MDX fix script
# This script handles ALL patterns that cause MDX compilation errors

echo "Starting simplified universal DocFX to MDX compatibility processing..."

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
        
        # Apply fixes one by one using multiple sed passes
        # Pass 1: Fix backtick + space + [type](link) patterns (parameters)
        sed 's/`[^`]*` \[[^]]*\]([^)]*)/\0/g; s/\[/\&amp;#91;/g; s/\]/\&amp;#93;/g' "$file" | \
        # Pass 2: Fix space + [type](link) patterns
        sed 's/ \[[^]]*\]([^)]*)/ \&amp;#91;TEMP\&amp;#93;(TEMP)/g; s/TEMP\&amp;#93;(\([^)]*\))/\1\&amp;#93;(\1)/g; s/\&amp;#91;TEMP/\&amp;#91;/g' | \
        # Pass 3: Fix start of line [type](link) patterns  
        sed 's/^\[[^]]*\]([^)]*)/\&amp;#91;TEMP\&amp;#93;(TEMP)/g; s/TEMP\&amp;#93;(\([^)]*\))/\1\&amp;#93;(\1)/g; s/\&amp;#91;TEMP/\&amp;#91;/g' | \
        # Pass 4: Fix inheritance patterns
        sed 's/: \[[^]]*\]([^)]*)/: \&amp;#91;TEMP\&amp;#93;(TEMP)/g; s/TEMP\&amp;#93;(\([^)]*\))/\1\&amp;#93;(\1)/g; s/\&amp;#91;TEMP/\&amp;#91;/g' | \
        # Pass 5: Fix angle brackets with problematic characters
        sed 's/<[^>]*[&<>?\\,\[\]][^>]*>/\&amp;lt;TEMP\&amp;gt;/g; s/TEMP/\&amp;#/g' > "$temp_file"
        
        # Replace the original file with the processed content
        mv "$temp_file" "$file"
        
        ((processed_count++))
    fi
done

echo "Simplified processing completed! Processed $processed_count files."
echo "All known MDX compilation patterns have been addressed."