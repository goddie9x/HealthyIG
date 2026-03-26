#!/bin/bash

################################################################################
# Description: Replaces Instagram feed endpoints to block Reels and Explore
# Note: This script is designed to run within the decompiled APK directory
################################################################################

# Get the script's own name to exclude it from processing
script_name=$(basename "$0")
target_directory="."

# Check if tqdm is installed for a better progress bar experience
HAS_TQDM=false
if command -v tqdm &> /dev/null; then
    HAS_TQDM=true
fi

# Define the endpoint replacements in an associative array
declare -A replacements

# --- Explore & Main Feed ---
replacements["discover/topical_explore/"]=""
replacements["feed/timeline/"]=""

# --- Reels / Clips ---
replacements["clips/discover/"]=""
replacements["clips/discover/social/"]=""
replacements["discover/explore_clips/"]=""
replacements["clips/discover/stream/"]=""
replacements["clips/suggested_template"]=""
replacements["clips/trend/"]=""
replacements["discover/discover_similar_clips/"]=""
replacements["/suggested_content/"]=""
replacements["clips/home/"]=""
replacements["clips/chaining/"]=""
replacements["clips/recommended_label/"]=""
replacements["/clips_media_feed/"]=""

# 1. Generate a temporary sed script for batch processing
sed_script=$(mktemp)
for old in "${!replacements[@]}"; do
    new="${replacements[$old]}"
    # Use | as a delimiter since URLs contain forward slashes
    echo "s|$old|$new|g" >> "$sed_script"
done

echo "🚀 Scanning files and breaking endpoints... Please wait!"

# 2. Collect files and count them for the progress bar
file_list=$(mktemp)
# Exclude the script itself, apk files, and hidden directories
find "$target_directory" -type f ! -name "$script_name" ! -name "*.apk" ! -path "*/.*" > "$file_list"
file_count=$(wc -l < "$file_list")

# 3. Execute replacements using parallel processing for speed
if [ "$HAS_TQDM" = true ]; then
    echo "Processing $file_count files with tqdm progress bar..."
    cat "$file_list" | tqdm --total="$file_count" --desc "Modifying" --unit "file" | xargs -d '\n' -P 4 -n 50 sed -i -f "$sed_script"
else
    echo "⚠️ tqdm not found (pip3 install tqdm). Running in standard mode..."
    cat "$file_list" | xargs -d '\n' -P 4 -n 50 sed -i -f "$sed_script"
fi

# 4. Cleanup temporary files
rm "$sed_script"
rm "$file_list"

echo -e "\n✅ Success: All target endpoints have been replaced!"