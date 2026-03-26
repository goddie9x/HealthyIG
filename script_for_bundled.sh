#!/bin/bash

# --- CONFIGURATION ---
BASE_APK="./ig_original/base.apk"
SOURCE_DIR="ig_source"
FINAL_APK="patched.apk"
ALIGNED_APK="patched_aligned.apk"
INSTALL_APK="install.apk"
TEMP_SPLIT_DIR="split_files_temp"
APKTOOL_JAR="/usr/local/bin/apktool.jar"
KEYSTORE="patched_instagram_key.jks"
KS_PASS="foobar"
ALIAS="key0"

# Check if base.apk exists
if [ ! -f "$BASE_APK" ]; then
    echo "❌ Error: $BASE_APK not found!"
    exit 1
fi

echo "--- STEP 1: DECOMPILE (SKIP RESOURCES) ---"
# Use -r to avoid layouts.xml errors in Instagram v422+
java -Xmx4g -jar "$APKTOOL_JAR" d -r "$BASE_APK" -o "$SOURCE_DIR" -f

echo "--- STEP 2: APPLY ENDPOINT MODIFICATIONS ---"
# Execute the Smali replacement script
if [ -f "./script.sh" ]; then
    bash ./script.sh
else
    echo "⚠️ Warning: script.sh not found, skipping code modification."
fi

echo "--- STEP 3: REBUILD APK (SMALI ONLY) ---"
# Build the modified smali back into an APK
java -Xmx4g -jar "$APKTOOL_JAR" b "$SOURCE_DIR" -o "$FINAL_APK"

echo "--- STEP 4: MERGE RESOURCES FROM SPLIT APKS ---"
# Create temp directory for split resources
mkdir -p "$TEMP_SPLIT_DIR"

# Extract resources from all split APKs in current directory
for split in split_*.apk; do
    if [ -f "$split" ]; then
        echo "📦 Extracting: $split"
        unzip -qo "$split" -d "$TEMP_SPLIT_DIR"
    fi
done

# Inject resources/libs into the final patched APK
cd "$TEMP_SPLIT_DIR"
# Remove conflicting files before merging
rm -rf META-INF AndroidManifest.xml
zip -ur "../$FINAL_APK" . > /dev/null
cd ..

# Cleanup temporary files
rm -rf "$TEMP_SPLIT_DIR"

echo "--- STEP 5: OPTIMIZE WITH ZIPALIGN ---"
# Align the APK for better performance and signing compatibility
if command -v zipalign &> /dev/null; then
    sudo zipalign -f -v 4 "$FINAL_APK" "$ALIGNED_APK"
else
    echo "❌ Error: zipalign not installed (sudo apt install zipalign)"
    exit 1
fi

echo "--- STEP 6: SIGNING THE APK ---"
# Generate keystore if it doesn't exist
if [ ! -f "$KEYSTORE" ]; then
    echo "🔑 Generating new keypair..."
    sudo keytool -genkeypair -alias "$ALIAS" -keyalg RSA -keysize 4096 -validity 10000 \
    -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -dname "CN=HoangMinhTam, OU=Dev, O=KMedia, L=Hanoi, S=HN, C=VN"
fi

# Sign the aligned APK
# Using V1 and V2 schemes for maximum compatibility
if command -v apksigner &> /dev/null; then
    sudo apksigner sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" \
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
    --out "$INSTALL_APK" "$ALIGNED_APK"
    echo "✅ SUCCESS: $INSTALL_APK is ready for installation!"
else
    echo "❌ Error: apksigner not installed (sudo apt install apksigner)"
    exit 1
fi

# Final Cleanup
# rm "$FINAL_APK" "$ALIGNED_APK" # Uncomment to keep only the signed APK
echo "------------------------------------------"
echo "Mission accomplished! Install $INSTALL_APK on your device."
echo "------------------------------------------"