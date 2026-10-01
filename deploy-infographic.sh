#!/usr/bin/env bash
set -euo pipefail

REPO="infographic"
OWNER="standardgalactic"
BRANCH="main"

echo
echo "========================================"
echo " Deploying $OWNER/$REPO"
echo "========================================"
echo

# ------------------------------------------------------------
# Sanity checks
# ------------------------------------------------------------

command -v git >/dev/null 2>&1 || {
    echo "ERROR: git is not installed."
    exit 1
}

command -v gh >/dev/null 2>&1 || {
    echo "ERROR: GitHub CLI (gh) is not installed."
    exit 1
}

if [[ ! -f "index.html" ]]; then
    echo "ERROR: index.html not found."
    echo "Run this script from the infographic directory."
    exit 1
fi

if [[ ! -f "wall.html" ]]; then
    echo "ERROR: wall.html not found."
    exit 1
fi

if [[ ! -f "README.md" ]]; then
    echo "ERROR: README.md not found."
    exit 1
fi

if [[ ! -d "wall-thumbs" ]]; then
    echo "ERROR: wall-thumbs/ not found."
    echo "Run the wall builder first."
    exit 1
fi

# ------------------------------------------------------------
# GitHub authentication
# ------------------------------------------------------------

echo "Checking GitHub authentication..."

if ! gh auth status >/dev/null 2>&1; then
    echo
    echo "ERROR: gh is not authenticated."
    echo "Run:"
    echo
    echo "    gh auth login"
    echo
    exit 1
fi

# ------------------------------------------------------------
# Initialize git if necessary
# ------------------------------------------------------------

if [[ ! -d ".git" ]]; then

    echo
    echo "Initializing Git repository..."

    git init
    git branch -M "$BRANCH"

else

    echo
    echo "Existing Git repository found."

    git branch -M "$BRANCH"
fi

# ------------------------------------------------------------
# Create a small .gitignore
# ------------------------------------------------------------

cat > .gitignore <<'EOF'
.DS_Store
Thumbs.db
desktop.ini
__pycache__/
*.pyc
*~
EOF

touch .nojekyll

# ------------------------------------------------------------
# Add everything
# ------------------------------------------------------------

echo
echo "Adding archive files..."

git add \
    README.md \
    .gitignore \
    .nojekyll \
    index.html \
    wall.html \
    build-gallery.sh \
    build-wall.sh \
    sort-images.sh \
    wall-thumbs \
    admissibility-adversaria \
    art-design \
    bad-filenames \
    biology-life \
    cognition-neuroscience \
    continuation-geometry \
    food \
    history-religion \
    industrial-ecology \
    mathematics-logic \
    media-fiction \
    personal-projects \
    physics-cosmology \
    society-economics-politics \
    spherepop-mem8 \
    technology-computing \
    unsorted \
    writing-language-education

# ------------------------------------------------------------
# Show what is about to be committed
# ------------------------------------------------------------

echo
echo "Repository status:"
echo

git status --short

# ------------------------------------------------------------
# Commit
# ------------------------------------------------------------

if git diff --cached --quiet; then

    echo
    echo "Nothing new to commit."

else

    echo
    echo "Creating commit..."

    git commit -m "Create infographic image archive"
fi

# ------------------------------------------------------------
# Create GitHub repository if it doesn't exist
# ------------------------------------------------------------

echo
echo "Checking GitHub repository..."

if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then

    echo "Repository already exists."

else

    echo "Creating public repository $OWNER/$REPO..."

    gh repo create "$OWNER/$REPO" \
        --public \
        --description "Visual archive of infographics, diagrams, illustrations, and research images"

fi

# ------------------------------------------------------------
# Configure remote
# ------------------------------------------------------------

REMOTE_URL="git@github.com:$OWNER/$REPO.git"

if git remote get-url origin >/dev/null 2>&1; then

    CURRENT_REMOTE="$(git remote get-url origin)"

    if [[ "$CURRENT_REMOTE" != "$REMOTE_URL" ]]; then
        echo
        echo "Updating origin:"
        echo "  $CURRENT_REMOTE"
        echo "  -> $REMOTE_URL"

        git remote set-url origin "$REMOTE_URL"
    fi

else

    echo
    echo "Adding origin..."

    git remote add origin "$REMOTE_URL"
fi

# ------------------------------------------------------------
# Push
# ------------------------------------------------------------

echo
echo "Pushing $BRANCH..."

git push -u origin "$BRANCH"

# ------------------------------------------------------------
# Enable GitHub Pages
#
# Deploy directly from the root of the main branch.
# ------------------------------------------------------------

echo
echo "Configuring GitHub Pages..."

if gh api \
    "repos/$OWNER/$REPO/pages" \
    >/dev/null 2>&1
then

    echo "GitHub Pages is already configured."

    # Make sure it is pointing at main:/.
    gh api \
        --method PUT \
        "repos/$OWNER/$REPO/pages" \
        -f build_type="legacy" \
        -f source[branch]="$BRANCH" \
        -f source[path]="/" \
        >/dev/null

else

    echo "Enabling GitHub Pages..."

    gh api \
        --method POST \
        "repos/$OWNER/$REPO/pages" \
        -f build_type="legacy" \
        -f source[branch]="$BRANCH" \
        -f source[path]="/" \
        >/dev/null
fi

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------

echo
echo "========================================"
echo " Deployment complete"
echo "========================================"
echo
echo "Repository:"
echo "  https://github.com/$OWNER/$REPO"
echo
echo "Image Archive:"
echo "  https://$OWNER.github.io/$REPO/"
echo
echo "Chromatic Image Wall:"
echo "  https://$OWNER.github.io/$REPO/wall.html"
echo
echo "GitHub Pages may take a minute or two to publish."
echo
