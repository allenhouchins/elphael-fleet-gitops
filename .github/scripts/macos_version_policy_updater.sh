#!/bin/bash

# Variables
#AUTOMATION_TOKEN="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_OWNER="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_EMAIL="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
FILE_PATH="lib/mac/policies/mac-operating-system-up-to-date.yml"
BRANCH="main"
CHECKIN_BRANCH="automation-latest-macos-version"

# GitHub API URL
FILE_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE_PATH?ref=$BRANCH"

# Make the API request to get the file contents
response=$(curl -s -H "Authorization: token $AUTOMATION_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$FILE_URL")

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch file"
    exit 1
fi

# Extract the query line
query_line=$(echo "$response" | grep 'query:')

# Use grep and sed to extract the version number from the query line
version_number=$(echo "$query_line" | grep -oE "'[0-9]+\.[0-9]+(\.[0-9]+)?'" | sed "s/'//g")

# Output the version number
echo "Extracted version number: $version_number"

# Fetch the JSON data and extract the ProductVersion strings
highest_version=$(curl -s "https://sofafeed.macadmins.io/v1/macos_data_feed.json" | \
jq -r '.. | objects | select(has("ProductVersion")) | .ProductVersion' | sort -Vr | head -n 1)

# Output the result
echo "Highest Version: $highest_version"

# Compare versions and update the file if needed
if [ "$version_number" != "$highest_version" ]; then
    echo "Updating query line with the new version..."

    # Prepare the new query line
    new_query_line="query: SELECT 1 FROM os_version WHERE version >= '$highest_version';"

    # Update the response (make sure to match the correct format)
    updated_response=$(echo "$response" | sed "s/query: .*/$new_query_line/")

    # Create a temporary file for the update
    temp_file=$(mktemp)
    echo "$updated_response" > "$temp_file"

    # Commit changes to the repository
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"

    git clone "https://$AUTOMATION_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" repo
    cd repo
    cp "$temp_file" "$FILE_PATH"
    git add "$FILE_PATH"
    git commit -m "Update macOS version number to $highest_version"
    git push origin $CHECKIN_BRANCH

    cd ..
    rm -rf repo
    rm "$temp_file"
else
    echo "No updates needed; the version is the same."
fi
