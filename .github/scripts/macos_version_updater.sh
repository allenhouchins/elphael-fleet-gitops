#!/bin/sh

# Variables
GITHUB_TOKEN="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"  # Replace this with your PAT
REPO_OWNER="allenhouchins"
REPO_NAME="fleet-elphael-gitops"
FILE_PATH="lib/mac/policies/mac-operating-system-up-to-date.yml"
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
version_numbers=($(echo "$query_line" | grep -oE "'[0-9]+\.[0-9]+(\.[0-9]+)?" | sed "s/'//g"))

# Sort versions and assign to version_1 and version_2
if [[ "${version_numbers[0]}" < "${version_numbers[1]}" ]]; then
    version_1="${version_numbers[0]}"
    version_2="${version_numbers[1]}"
else
    version_1="${version_numbers[1]}"
    version_2="${version_numbers[0]}"
fi

# Output the version numbers
echo "Extracted version numbers:"
echo "Version 1 (lowest): $version_1"
echo "Version 2 (highest): $version_2"

# Fetch the JSON data and extract the ProductVersion strings
versions=$(curl -s "https://sofafeed.macadmins.io/v1/macos_data_feed.json" | \
jq -r '.. | objects | select(has("ProductVersion")) | .ProductVersion')

# Find the two highest major versions
highest_two_majors=$(echo "$versions" | cut -d '.' -f1 | sort -Vr | uniq | head -n 2)

# Initialize variables to store the highest versions
highest_version1=""
highest_version2=""

# Extract the highest version for each of the two highest major versions
count=1
for major in $highest_two_majors; do
  highest_version=$(echo "$versions" | grep "^$major\." | sort -Vr | head -n 1)
  
  if [ $count -eq 1 ]; then
    highest_version1="$highest_version"
  elif [ $count -eq 2 ]; then
    highest_version2="$highest_version"
  fi
  
  count=$((count + 1))
done

# Ensure highest_version1 is the lesser of the two
if [ "$(echo "$highest_version1" | cut -d '.' -f1)" -gt "$(echo "$highest_version2" | cut -d '.' -f1)" ]; then
  temp="$highest_version1"
  highest_version1="$highest_version2"
  highest_version2="$temp"
fi

# Output the results
echo "Lowest Version: $highest_version1"
echo "Highest Version: $highest_version2"

# Compare versions and update the file if needed
if [ "$version_1" != "$highest_version1" ] || [ "$version_2" != "$highest_version2" ]; then
    echo "Updating query line with new versions..."
    
    # Prepare the new query line
    new_query_line="query: SELECT 1 FROM os_version WHERE version >= '${highest_version1}' OR version >= '${highest_version2}';"
    
    # Update the response (make sure to match the correct format)
    updated_response=$(echo "$response" | sed "s/query: .*/$new_query_line/")
    
    #echo "$updated_response"  # For debugging, show the updated response

    # Create a temporary file for the update
    temp_file=$(mktemp)
    echo "$updated_response" > "$temp_file"

    # Commit changes to the repository
    git config --global user.name "Allen Houchins"
    git config --global user.email "allenhouchins@mac.com"
    
    git clone "https://$GITHUB_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" repo
    cd repo
    cp "$temp_file" "$FILE_PATH"
    git add "$FILE_PATH"
    git commit -m "Update macOS version numbers to $highest_version1 and $highest_version2"
    git push origin $BRANCH
    
    cd ..
    rm -rf repo
    rm "$temp_file"
else
    echo "No updates needed; the versions are the same."
fi

