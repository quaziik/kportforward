#!/bin/bash
#
# Install git hooks for the kportforward project
# This script sets up pre-commit hooks for Go code formatting
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks for kportforward..."

# Check if we're in a git repository
if [ ! -d "$REPO_ROOT/.git" ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Create the pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
#
# Git pre-commit hook for Go code formatting
# Automatically formats Go code with gofmt before commit
#

# Check if this is an initial commit
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    against=HEAD
else
    # Initial commit: diff against an empty tree object
    against=$(git hash-object -t tree /dev/null)
fi

# Get list of Go files that are staged for commit
gofiles=$(git diff --cached --name-only --diff-filter=ACM $against | grep '\.go$')

# Exit early if no Go files are staged
if [ -z "$gofiles" ]; then
    exit 0
fi

# Check if gofmt is available
if ! command -v gofmt >/dev/null 2>&1; then
    echo "Error: gofmt not found in PATH"
    echo "Please install Go or ensure gofmt is available"
    exit 1
fi

# Check if any Go files need formatting
unformatted=$(echo "$gofiles" | xargs gofmt -s -l)

if [ -n "$unformatted" ]; then
    echo "The following Go files need formatting:"
    echo "$unformatted"
    echo ""
    echo "Running gofmt -s -w on staged Go files..."
    
    # Format the files
    echo "$gofiles" | xargs gofmt -s -w
    
    # Add the formatted files back to staging
    echo "$gofiles" | xargs git add
    
    echo "Go files have been formatted and re-staged."
    echo "Please review the changes and commit again."
    
    # Show which files were formatted
    echo ""
    echo "Formatted files:"
    echo "$unformatted"
fi

exit 0
EOF

# Make the hook executable
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The hook will automatically format Go code with 'gofmt -s -w' before each commit."
echo "If files are formatted, the commit will be aborted so you can review the changes."
echo ""
echo "To bypass the hook for a specific commit (not recommended), use:"
echo "  git commit --no-verify"