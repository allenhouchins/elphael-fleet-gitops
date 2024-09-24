#!/bin/bash

# Variables
#AUTOMATION_TOKEN="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_OWNER="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_EMAIL="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
FILE_PATH="lib/mac/policies/mac-google-chrome-up-to-date.yml"
BRANCH="main"

# GitHub API URL
FILE_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE_PATH?ref=$BRANCH"

# Make the API request to get the file contents
response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$FILE_URL")

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch file"
    exit 1
fi

# Extract the query line
query_line=$(echo "$response" | grep 'query:')

# Use grep and sed to extract version numbers from the query line
version_number=$(echo "$query_line" | grep -oE "'[0-9]+(\.[0-9]+)*" | sed "s/'//g" | head -n 1)

echo "Policy version: $version_number"

# Define the temp file location
TMP_FILE="/tmp/cask.json"

# Token name in Brew
TOKEN_NAME="google-chrome"

# Download the JSON data to the temporary file
curl -s --compressed "https://formulae.brew.sh/api/cask.json" -o "$TMP_FILE"

# Use trap to ensure the temporary file is deleted when the script exits
trap 'rm -f "$TMP_FILE"' EXIT

# Validate JSON data using jq (with explicit error output redirected)
jq empty "$TMP_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Invalid JSON data. Aborting."
    exit 1
fi

# Use jq to extract the version based on the app name or token
latest_chrome_version=$(jq -r --arg TOKEN_NAME "$TOKEN" '.[] | select(.token == $TOKEN_NAME) | .version' "$TMP_FILE")

echo "Latest Chrome version: $latest_chrome_version"

# Compare versions and update the file if needed
if [ "$latest_chrome_version" != "$version_number" ]; then
    echo "Updating query line with new versions..."
    
    # Prepare the new query line
    new_query_line="query: SELECT 1 FROM apps WHERE name = 'Google Chrome.app' AND version_compare(bundle_short_version, '$latest_chrome_version') >= 0;"
    
    # Update the response (make sure to match the correct format)
    updated_response=$(echo "$response" | sed "s/query: .*/$new_query_line/")
    
    # echo "$updated_response"  # For debugging, show the updated response

    # Create a temporary file for the update
    temp_file=$(mktemp)
    echo "$updated_response" > "$temp_file"

    # Commit changes to the repository
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    
    git clone "https://$GITHUB_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" repo
    cd repo
    cp "$temp_file" "$FILE_PATH"
    git add "$FILE_PATH"
    git commit -m "Update Google Chrome version number to $latest_chrome_version"
    git push origin $BRANCH
    
    cd ..
    rm -rf repo
    rm "$temp_file"
else
    echo "No updates needed; the versions are the same."
fi
