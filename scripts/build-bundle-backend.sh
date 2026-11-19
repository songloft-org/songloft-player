#!/usr/bin/env bash
set -euo pipefail

target=${1:?usage: build-bundle-backend.sh <android|ios|linux|windows|macos-universal> [output]}
output=${2:-}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
backend_root=${SONGLOFT_BACKEND_SOURCE:-"$repo_root/backend-source"}
commit=$(git -C "$backend_root" rev-parse HEAD)
if [[ "$commit" != "${SONGLOFT_BACKEND_COMMIT:-$commit}" ]]; then
  echo "Backend checkout does not match the commit selected for this build: $commit" >&2
  exit 1
fi
version=$(git -C "$backend_root" show "$commit:main.go" | sed -n 's|^// @version ||p')
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version in backend commit $commit" >&2
  exit 1
fi
[[ -s "$backend_root/mobile/export_surface.txt" ]]

build_time=${BUILD_TIME:-$(date -u '+%Y-%m-%d_%H:%M:%S')}
ldflags="-s -w -X songloft/internal/version.Version=$version -X songloft/internal/version.GitCommit=$commit -X songloft/internal/version.BuildTime=$build_time -X songloft/internal/version.BuildType=lite"

install_gomobile() {
  local gomobile_version
  gomobile_version=$(cd "$backend_root" && go list -m -f '{{.Version}}' golang.org/x/mobile)
  [[ "$gomobile_version" == v* ]]
  go install "golang.org/x/mobile/cmd/gomobile@$gomobile_version" \
    "golang.org/x/mobile/cmd/gobind@$gomobile_version"
  # gomobile builds in temporary modules. The backend SHA is injected above.
  export GOFLAGS="${GOFLAGS:+$GOFLAGS }-buildvcs=false"
}

case "$target" in
  android)
    : "${output:=$repo_root/android/app/libs/songloft.aar}"
    mkdir -p "$(dirname "$output")"
    install_gomobile
    (cd "$backend_root" && gomobile bind -v -target=android/arm64,android/arm,android/amd64 \
      -androidapi 23 -tags lite -ldflags="$ldflags" -o "$output" ./mobile)
    ;;
  ios)
    : "${output:=$repo_root/ios/Songloft.xcframework}"
    mkdir -p "$(dirname "$output")"
    install_gomobile
    (cd "$backend_root" && gomobile bind -v -target=ios/arm64 -tags lite \
      -ldflags="$ldflags" -o "$output" ./mobile)
    cat > "$repo_root/ios/Flutter/SongloftBackend.xcconfig" <<'EOF'
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) HAS_SONGLOFT_BACKEND
FRAMEWORK_SEARCH_PATHS = $(inherited) "$(SRCROOT)/Songloft.xcframework/ios-arm64"
OTHER_LDFLAGS = $(inherited) -framework Songloft
EOF
    ;;
  linux)
    : "${output:=$repo_root/linux/runner/songloft-server}"
    mkdir -p "$(dirname "$output")"
    (cd "$backend_root" && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags lite \
      -ldflags="$ldflags" -o "$output" .)
    ;;
  windows)
    : "${output:=$repo_root/windows/runner/songloft-server.exe}"
    mkdir -p "$(dirname "$output")"
    (cd "$backend_root" && CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -tags lite \
      -ldflags="$ldflags" -o "$output" .)
    ;;
  macos-universal)
    : "${output:=$repo_root/macos/Runner/songloft-server}"
    mkdir -p "$(dirname "$output")"
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    (cd "$backend_root" && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -tags lite \
      -ldflags="$ldflags" -o "$temp_dir/songloft-arm64" .)
    (cd "$backend_root" && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -tags lite \
      -ldflags="$ldflags" -o "$temp_dir/songloft-amd64" .)
    lipo -create "$temp_dir/songloft-arm64" "$temp_dir/songloft-amd64" -output "$output"
    ;;
  *)
    echo "unsupported backend target: $target" >&2
    exit 2
    ;;
esac

echo "Built $target backend from $commit: $output"
