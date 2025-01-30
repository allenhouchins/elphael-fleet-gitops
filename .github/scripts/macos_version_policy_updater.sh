#!/bin/bash

# Variables
FILE_PATH="lib/mac/policies/mac-operating-system-up-to-date.yml"
BRANCH="main"
NEW_BRANCH="update-macos-version-$(date +%s)"

# GitHub API URL
FILE_URL="https://api.github.com/repos/allenhouchins/elphael-fleet-gitops/contents/$FILE_PATH?ref=$BRANCH"

# Make the API request to get the file contents
response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$FILE_URL")

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch file"
    exit 1
fi

# Extract the query line
query_line=$(echo "$response" | grep 'query:')

# Extract the version number from the query line
version_number=$(echo "$query_line" | grep -oE "'[0-9]+\.[0-9]+(\.[0-9]+)?'" | sed "s/'//g")

# Output the version number
echo "Extracted version number: $version_number"

# Fetch the highest available macOS version
highest_version=$(curl -s "https://sofafeed.macadmins.io/v1/macos_data_feed.json" | \
jq -r '.. | objects | select(has("ProductVersion")) | .ProductVersion' | sort -Vr | head -n 1)

echo "Highest Version: $highest_version"

# Compare versions and update the file if needed
if [ "$version_number" != "$highest_version" ]; then
    echo "Updating query line with the new version..."

    # Prepare the new query line
    new_query_line="query: SELECT 1 FROM os_version WHERE version >= '$highest_version';"

    # Update the response
    updated_response=$(echo "$response" | sed "s/query: .*/$new_query_line/")

    # Create a temporary file for the update
    temp_file=$(mktemp)
    echo "$updated_response" > "$temp_file"

    # Configure Git
    git config --global user.name "github-actions"
    git config --global user.email "github-actions@github.com"

    # Clone the repository using GitHub Token
    git clone "https://oauth2:$GITHUB_TOKEN@github.com/allenhouchins/fleet-elphael-gitops.git" repo
    cd repo
    git checkout -b "$NEW_BRANCH"

    # Apply changes
    cp "$temp_file" "$FILE_PATH"
    git add "$FILE_PATH"
    git commit -m "Update macOS version number to $highest_version"
    git push origin "$NEW_BRANCH"

    # Create a pull request using GITHUB_TOKEN
    pr_data=$(jq -n --arg title "Update macOS version number to $highest_version" \
                 --arg head "$NEW_BRANCH" \
                 --arg base "$BRANCH" \
                 '{title: $title, head: $head, base: $base}')

    curl -s -X POST \
         -H "Authorization: Bearer $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         -d "$pr_data" \
         "https://api.github.com/repos/allenhouchins/fleet-elphael-gitops/pulls"

    cd ..
    rm -rf repo
    rm "$temp_file"
else
    echo "No updates needed; the version is the same."
fi
