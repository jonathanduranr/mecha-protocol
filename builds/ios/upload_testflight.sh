#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=== 1. Exporting Xcode project from Godot ==="
godot --headless --path ../.. --export-release "iOS" "$DIR/MechaProtocol.ipa"

echo "=== 2. Adjusting Code Signing & Sanitizing Info.plist ==="
sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution";/CODE_SIGN_IDENTITY = "Apple Development";/g' MechaProtocol.xcodeproj/project.pbxproj

python3 -c '
import plistlib
plist_path = "MechaProtocol/MechaProtocol-Info.plist"
with open(plist_path, "rb") as f:
    pl = plistlib.load(f)

# 1. Eliminar permisos innecesarios con cadenas vacías (prevención de rechazos y crashes de seguridad)
for key in ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription", "NSMicrophoneUsageDescription"]:
    pl.pop(key, None)

# 2. Orientaciones para iPhone
pl["UISupportedInterfaceOrientations"] = [
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationPortraitUpsideDown"
]

# 3. Orientaciones para iPad (Evita crash fatal UIApplicationInvalidInterfaceOrientation si Apple prueba en iPad horizontal)
pl["UISupportedInterfaceOrientations~ipad"] = [
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationPortraitUpsideDown",
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight"
]

pl["UIRequiresFullScreen"] = True

with open(plist_path, "wb") as f:
    plistlib.dump(pl, f)
print("MechaProtocol-Info.plist sanitizado exitosamente.")
'

echo "=== 3. Creating Release Archive ==="
xcodebuild archive \
  -project MechaProtocol.xcodeproj \
  -scheme MechaProtocol \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath ./build/MechaProtocol.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/jonathanduran/.appstoreconnect/private_keys/AuthKey_55Q86R2474.p8 \
  -authenticationKeyID 55Q86R2474 \
  -authenticationKeyIssuerID 69ed3a65-f0c8-4c37-bfcb-89bd3891151d

echo "=== 4. Uploading to TestFlight / App Store Connect ==="
xcodebuild -exportArchive \
  -archivePath ./build/MechaProtocol.xcarchive \
  -exportOptionsPlist ./ExportOptions.plist \
  -authenticationKeyPath /Users/jonathanduran/.appstoreconnect/private_keys/AuthKey_55Q86R2474.p8 \
  -authenticationKeyID 55Q86R2474 \
  -authenticationKeyIssuerID 69ed3a65-f0c8-4c37-bfcb-89bd3891151d

echo "=== Build and upload to TestFlight completed successfully! ==="
