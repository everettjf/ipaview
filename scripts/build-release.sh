#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
raw_version="${1:-}"
version="${raw_version#v}"
output_dir="${2:-$project_root/dist}"
derived_data="${IPAVIEW_DERIVED_DATA:-$(mktemp -d "${RUNNER_TEMP:-/tmp}/ipaview-release.XXXXXX")}"

if [[ -z "$version" ]]; then
  echo "usage: $0 <version> [output-directory]" >&2
  exit 64
fi

mkdir -p "$output_dir" "$derived_data"
xcodebuild -project "$project_root/IPAView/IPAView.xcodeproj" -scheme IPAView -configuration Release -destination 'platform=macOS' -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO MARKETING_VERSION="$version" build

app_path="$derived_data/Build/Products/Release/IPAView.app"
archive="$output_dir/IPAView-$version.zip"
identity="${IPAVIEW_SIGNING_IDENTITY:--}"
signing_options=(--force --deep --options runtime --entitlements "$project_root/IPAView/IPAView/IPAView.entitlements" --sign "$identity")
if [[ "$identity" == "-" ]]; then signing_options+=(--timestamp=none); else signing_options+=(--timestamp); fi

codesign "${signing_options[@]}" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive"
(cd "$output_dir" && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
echo "Created $archive"
