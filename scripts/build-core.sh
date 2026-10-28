#!/bin/zsh
# Build lõi Rust cho Apple silicon và Intel, gộp thành Frameworks/MrTVCore.xcframework.
#   scripts/build-core.sh            bản release
#   scripts/build-core.sh debug      bản debug, build nhanh hơn
set -euo pipefail
source "${0:A:h}/lib.sh"

PROFILE=release
if [[ "${1:-}" == "debug" || "${1:-}" == "release" ]]; then
  PROFILE="$1"
  shift
fi
reject_args "scripts/build-core.sh [debug|release]" "$@"

command -v cargo >/dev/null || fail "Chưa có Rust. Chạy: scripts/bootstrap.sh"
FLAG=()
[[ "$PROFILE" == "release" ]] && FLAG=(--release)

step "Build lõi Rust ($PROFILE)"
cd "$ROOT/core"
for target in aarch64-apple-darwin x86_64-apple-darwin; do
  cargo build --quiet -p mrtv-ffi --target "$target" "${FLAG[@]}"
  ok "$target"
done

OUT="$ROOT/build/core"
rm -rf "$OUT" "$ROOT/Frameworks/MrTVCore.xcframework"
mkdir -p "$OUT/include" "$ROOT/Frameworks"
lipo -create \
  "target/aarch64-apple-darwin/$PROFILE/libmrtv_ffi.a" \
  "target/x86_64-apple-darwin/$PROFILE/libmrtv_ffi.a" \
  -output "$OUT/libmrtv_ffi.a"
cp mrtv-ffi/include/mrtv.h "$OUT/include/"
cat > "$OUT/include/module.modulemap" <<'EOF'
module MrTVCoreFFI {
  header "mrtv.h"
  export *
}
EOF
xcodebuild -create-xcframework -library "$OUT/libmrtv_ffi.a" -headers "$OUT/include" \
  -output "$ROOT/Frameworks/MrTVCore.xcframework" >/dev/null
ok "Frameworks/MrTVCore.xcframework ($(lipo -archs "$OUT/libmrtv_ffi.a"))"
