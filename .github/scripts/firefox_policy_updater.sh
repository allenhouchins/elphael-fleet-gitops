#!/bin/bash

# Variables
#AUTOMATION_TOKEN="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_OWNER="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#REPO_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_NAME="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
#GIT_USER_EMAIL="XXX"  # Uncomment and replace this with your token if running locally, configure it as secret in GitHub if run via Action
MAC_FILE_PATH="lib/mac/policies/mac-firefox-up-to-date.yml"
#WIN_FILE_PATH="lib/win/policies/win-google-chrome-up-to-date.yml"
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

# Use jq to extract the version based on the app name or token
latest_firefox_version=$(curl -s https://product-details.mozilla.org/1.0/firefox_versions.json | jq -r '.LATEST_FIREFOX_VERSION')

echo "Latest Chrome version for macOS: $latest_firefox_version"

# Compare versions and update the file if needed
if [ "$latest_firefox_version" != "$mac_version_number" ]; then
    echo "Updating query line with new versions..."
    
    # Prepare the new query line
    new_mac_query_line="query: SELECT 1 FROM apps WHERE name = 'Firefox.app' AND version_compare(bundle_short_version, '$latest_firefox_version') >= 0;"
    
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
    git commit -m "Update Firefox version number for macOS to $latest_firefox_version"
    git push origin $BRANCH
    
    cd ..
    rm -rf repo
    rm "$mac_temp_file"
else
    echo "No updates needed for macOS; the versions are the same."
fi

# ##### Begin Windows #####
# # GitHub API URL
# WIN_FILE_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$WIN_FILE_PATH?ref=$BRANCH"

# # Make the API request to get the file contents
# win_response=$(curl -s -H "Authorization: token $AUTOMATION_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$WIN_FILE_URL")

# # Check if the request was successful
# if [ $? -ne 0 ]; then
#     echo "Failed to fetch file"
#     exit 1
# fi

# # Extract the query line
# win_query_line=$(echo "$win_response" | grep 'query:')

# # Use grep and sed to extract version numbers from the query line
# win_version_number=$(echo "$win_query_line" | grep -oE "'[0-9]+(\.[0-9]+)*" | sed "s/'//g" | head -n 1)

# echo "Windows policy version: $win_version_number"

# # URL of the JSON file to check for latest versions
# url="https://raw.githubusercontent.com/berstend/chrome-versions/master/data/stable/windows/version/latest.json"

# # Fetch the JSON file and parse the 'version' value
# win_latest_chrome_version=$(curl -s $url | jq -r '.version')

# echo "Latest Chrome version for Windows: $win_latest_chrome_version"

# # Compare versions and update the file if needed
# if [ "$win_latest_chrome_version" != "$win_version_number" ]; then
#     echo "Updating query line with new versions..."
    
#     # Prepare the new query line
#     new_win_query_line="query: SELECT 1 FROM apps WHERE name = 'Google Chrome.app' AND version_compare(bundle_short_version, '$win_latest_chrome_version') >= 0;"
    
#     # Update the response (make sure to match the correct format)
#     updated_win_response=$(echo "$win_response" | sed "s/query: .*/$new_win_query_line/")
    
#     # echo "$updated_response"  # For debugging, show the updated response

#     # Create a temporary file for the update
#     win_temp_file=$(mktemp)
#     echo "$updated_win_response" > "$win_temp_file"

#     # Commit changes to the repository
#     git config --global user.name "$GIT_USER_NAME"
#     git config --global user.email "$GIT_USER_EMAIL"
    
#     git clone "https://$AUTOMATION_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" repo
#     cd repo
#     cp "$win_temp_file" "$WIN_FILE_PATH"
#     git add "$WIN_FILE_PATH"
#     git commit -m "Update Google Chrome version number for Windows to $win_latest_chrome_version"
#     git push origin $BRANCH
    
#     cd ..
#     rm -rf repo
#     rm "$win_temp_file"
# else
#     echo "No updates needed for Windows; the versions are the same."
# fi

exit 0
