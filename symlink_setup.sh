#!/bin/bash
# File: create_symlinks.sh
# Creates symlinks from inst/scripts/ to root directory

# Check if we're on a system that supports symlinks
if ! command -v ln &> /dev/null; then
    echo "❌ Symlinks not supported on this system"
    exit 1
fi

# Create symlinks for script files
echo "🔗 Creating symlinks for script files..."

# Define files to symlink
declare -a files=(
    "setup_template_repo.R"
    "batch_domain_processor.R" 
    "template_integration.R"
    "main_workflow_runner.R"
)

# Create symlinks
for file in "${files[@]}"; do
    source_path="inst/scripts/$file"
    target_path="$file"
    
    if [ -f "$source_path" ]; then
        # Remove existing file/symlink if it exists
        if [ -f "$target_path" ] || [ -L "$target_path" ]; then
            echo "  Removing existing $target_path"
            rm "$target_path"
        fi
        
        # Create symlink
        ln -s "$source_path" "$target_path"
        echo "  ✅ Created symlink: $target_path -> $source_path"
    else
        echo "  ⚠️  Source file not found: $source_path"
    fi
done

# Update .gitignore to handle symlinks appropriately
echo ""
echo "📝 Updating .gitignore..."

gitignore_entries="
# Symlinked scripts (optional - you can track these)
# setup_template_repo.R
# batch_domain_processor.R
# template_integration.R
# main_workflow_runner.R
"

if ! grep -q "# Symlinked scripts" .gitignore 2>/dev/null; then
    echo "$gitignore_entries" >> .gitignore
    echo "  ✅ Added symlink entries to .gitignore (commented out)"
    echo "  💡 Uncomment these lines if you don't want to track the symlinks"
fi

echo ""
echo "🎉 Symlink setup complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Test the symlinked scripts: Rscript setup_template_repo.R"
echo "  2. If paths break, use the wrapper script approach instead"
echo "  3. Consider uncommenting symlinks in .gitignore if needed"