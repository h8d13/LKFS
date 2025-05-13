#!/bin/bash

# Function to build and display the tree structure from HL tags
display_hl_tree() {
    local temp_file=$(mktemp)
    
    echo "[-] Searching for files with #HL# tags..."
    
    # Find all files containing the HL tag pattern recursively
    find . -type f -exec grep -l "^#HL#.*#" {} \; | while read -r file; do
        # Extract the path from the HL tag
        hl_path=$(grep "^#HL#" "$file" | head -n 1 | sed 's/^#HL#\(.*\)#/\1/')
        
        if [ -n "$hl_path" ]; then
            echo "$hl_path" >> "$temp_file"
        fi
    done
    
    if [ ! -s "$temp_file" ]; then
        echo "[-] No files with #HL# tags found."
        rm "$temp_file"
        return 1
    fi
    
    echo "[-] Found paths from tags."
    ## Debug
    #cat "$temp_file"
    echo ""
    
    echo "[-] Generating tree structure:"
    echo ""
    
    # Check if tree command is available
    if ! command -v tree &> /dev/null; then
        echo "Error: 'tree' command not found. Please install it first."
        rm "$temp_file"
        return 1
    fi
    
    # Create a temporary directory to represent the tree structure
    local tree_dir=$(mktemp -d)
    
    # Create empty files to represent the tree structure
    while read -r path; do
        mkdir -p "$(dirname "$tree_dir/$path")"
        touch "$tree_dir/$path"
    done < "$temp_file"
    
    # Display the tree structure
    tree "$tree_dir"
    
    # Clean up temporary files
    rm "$temp_file"
    rm -rf "$tree_dir"
}

# Call the function
display_hl_tree