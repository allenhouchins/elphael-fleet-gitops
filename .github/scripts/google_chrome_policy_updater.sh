#!/bin/bash

# Variables
#AUTOMATION_TOKEN="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_OWNER="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_EMAIL="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
MAC_FILE_PATH="lib/mac/policies/mac-google-chrome-up-to-date.yml"
WIN_FILE_PATH="lib/win/policies/win-google-chrome-up-to-date.yml"
BRANCH="main"

##### Begin macOS #####
# GitHub API URL
MAC_FILE_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$MAC_FILE_PATH?ref=$BRANCH"

# Make the API request to get the file contents
mac_response=$(curl -s -H "Authorization: token $AUTOMATION_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$MAC_FILE_URL")

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch file"
    exit 1
fi

# Extract the query line
mac_query_line=$(echo "$mac_response" | grep 'query:')

# Use grep and sed to extract version numbers from the query line
mac_version_number=$(echo "$mac_query_line" | grep -oE "'[0-9]+(\.[0-9]+)*" | sed "s/'//g" | head -n 1)

echo "macOS policy version: $mac_version_number"

# Define the temp file location
MAC_TMP_FILE="/tmp/cask.json"

# Token name in Brew
TOKEN_NAME="google-chrome"

# Download the JSON data to the temporary file
curl -s --compressed "https://formulae.brew.sh/api/cask.json" -o "$MAC_TMP_FILE"

# Use trap to ensure the temporary file is deleted when the script exits
trap 'rm -f "$MAC_TMP_FILE"' EXIT

# Validate JSON data using jq (with explicit error output redirected)
jq empty "$MAC_TMP_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Invalid JSON data. Aborting."
    exit 1
fi

# Use jq to extract the version based on the app name or token
mac_latest_chrome_version=$(jq -r --arg TOKEN_NAME "$TOKEN_NAME" '.[] | select(.token == $TOKEN_NAME) | .version' "$MAC_TMP_FILE")

echo "Latest Chrome version for macOS: $mac_latest_chrome_version"

# Compare versions and update the file if needed
if [ "$mac_latest_chrome_version" != "$mac_version_number" ]; then
    echo "Updating query line with new versions..."
    
    # Prepare the new query line
    new_mac_query_line="query: SELECT 1 FROM apps WHERE name = 'Google Chrome.app' AND version_compare(bundle_short_version, '$mac_latest_chrome_version') >= 0;"
    
    # Update the response (make sure to match the correct format)
    updated_mac_response=$(echo "$mac_response" | sed "s/query: .*/$new_mac_query_line/")
    
    # echo "$updated_response"  # For debugging, show the updated response

    # Create a temporary file for the update
    mac_temp_file=$(mktemp)
    echo "$updated_mac_response" > "$mac_temp_file"

    # Commit changes to the repository
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    
    git clone "https://$AUTOMATION_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" repo
    cd repo
    cp "$mac_temp_file" "$MAC_FILE_PATH"
    git add "$MAC_FILE_PATH"
    git commit -m "Update Google Chrome version number for macOS to $mac_latest_chrome_version"
    git push origin $BRANCH
    

## Tell packages repo to build latest version of Firefox package
    # Variables
    #PACKAGES_REPO_OWNER="xxx"
    #PACKAGES_REPO_NAME="elphael-fleet-packages"
    WORKFLOW_ID="google_chrome.yml"  # This can be either the workflow file name (e.g., main.yml) or its ID
    BRANCH="main"  # Branch where the workflow will run
    #ACTIONS_DISPATCHER="xxx"  # Set your GitHub PAT here

    # GitHub API URL
    API_URL="https://api.github.com/repos/$PACKAGES_REPO_OWNER/$PACKAGES_REPO_NAME/actions/workflows/$WORKFLOW_ID/dispatches"

    # Trigger the workflow using a curl POST request
    curl -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token $ACTIONS_DISPATCHER" \
        $API_URL \
        -d "{\"ref\":\"$BRANCH\"}"

    # Optional: Check for successful response
    if [ $? -eq 0 ]; then
        echo "Workflow triggered successfully"
    else
        echo "Failed to trigger workflow"
    fi
else
    echo "No updates needed for macOS; the versions are the same."
fi



##### Begin Windows #####
# GitHub API URL
WIN_FILE_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$WIN_FILE_PATH?ref=$BRANCH"

# Make the API request to get the file contents
win_response=$(curl -s -H "Authorization: token $AUTOMATION_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$WIN_FILE_URL")

# Check if the request was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch file"
    exit 1
fi

# Extract the query line
win_query_line=$(echo "$win_response" | grep 'query:')

# Use grep and sed to extract version numbers from the query line
win_version_number=$(echo "$win_query_line" | grep -oE "'[0-9]+(\.[0-9]+)*" | sed "s/'//g" | head -n 1)

echo "Windows policy version: $win_version_number"

# URL of the JSON file to check for latest versions
url="https://raw.githubusercontent.com/berstend/chrome-versions/master/data/stable/windows/version/latest.json"

# Fetch the JSON file and parse the 'version' value
win_latest_chrome_version=$(curl -s $url | jq -r '.version')

echo "Latest Chrome version for Windows: $win_latest_chrome_version"

# Compare versions and update the file if needed
if [ "$win_latest_chrome_version" != "$win_version_number" ]; then
    echo "Updating query line with new versions..."
    
    # Prepare the new query line
    new_win_query_line="query: SELECT 1 FROM apps WHERE name = 'Google Chrome.app' AND version_compare(bundle_short_version, '$win_latest_chrome_version') >= 0;"
    
    # Update the response (make sure to match the correct format)
    updated_win_response=$(echo "$win_response" | sed "s/query: .*/$new_win_query_line/")
    
    # echo "$updated_response"  # For debugging, show the updated response

    # Create a temporary file for the update
    win_temp_file=$(mktemp)
    echo "$updated_win_response" > "$win_temp_file"

    # Commit changes to the repository
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    
    git clone "https://$AUTOMATION_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" repo
    cd repo
    cp "$win_temp_file" "$WIN_FILE_PATH"
    git add "$WIN_FILE_PATH"
    git commit -m "Update Google Chrome version number for Windows to $win_latest_chrome_version"
    git push origin $BRANCH
    
    cd ..
    rm -rf repo
    rm "$win_temp_file"
else
    echo "No updates needed for Windows; the versions are the same."
fi

exit 0

