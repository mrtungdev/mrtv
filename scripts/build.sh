#!/bin/zsh
# Build ứng dụng Mr TV (kèm bộ gõ bên trong). Kết quả: build/<Debug|Release>/MrTV.app
#   scripts/build.sh            bản Release, chạy cả Intel và Apple silicon
#   scripts/build.sh debug      bản Debug, chỉ cho máy đang dùng
set -euo pipefail
source "${0:A:h}/lib.sh"

CONFIG=Release
if [[ "${1:-}" == "debug" ]]; then CONFIG=Debug; shift
elif [[ "${1:-}" == "release" ]]; then shift
fi
reject_args "scripts/build.sh [debug|release]" "$@"

"$ROOT/scripts/build-core.sh" "${(L)CONFIG}"
"$ROOT/scripts/gen-project.sh"
step "Build MrTV.app ($CONFIG)"
xcb -scheme MrTV -configuration "$CONFIG" build

OUT="$ROOT/build/$CONFIG"
rm -rf "$OUT/MrTV.app"
mkdir -p "$OUT"
cp -R "$ROOT/build/DerivedData/Build/Products/$CONFIG/MrTV.app" "$OUT/"
APP="$OUT/MrTV.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ok "build/$CONFIG/MrTV.app · bản $VERSION · $(lipo -archs "$APP/Contents/MacOS/MrTV") · $(du -sh "$APP" | cut -f1)"

# Mở thử cả hai tiến trình ở chế độ --self-test: bắt được lỗi thiếu thư viện, sai chữ ký
# (ứng dụng văng ngay khi mở) và lỗi lõi gõ, trước khi đưa cho người dùng.
step "Mở thử"
# Sparkle đi kèm mang chữ ký của nhóm Sparkle; ký lại cả gói để mọi phần cùng một chữ ký.
# Có chứng chỉ "Apple Development" thì ký bằng nó: macOS nhận ra vẫn là ứng dụng cũ sau mỗi lần build,
# nên giữ nguyên quyền Trợ năng và Giám sát đầu vào. Ký tạm (ad-hoc) thì mỗi bản build là một ứng dụng
# mới với macOS, quyền cũ mất tác dụng dù công tắc trong Cài đặt hệ thống vẫn bật.
# Chọn chứng chỉ khác: MRTV_SIGN_IDENTITY="<SHA-1 hoặc tên>" make install. Bản phát hành do
# scripts/release.sh ký lại bằng Developer ID.
# Có nhiều chứng chỉ thì luôn lấy cùng một cái (xếp theo mã SHA-1): đổi chứng chỉ là mất quyền.
IDENTITY="${MRTV_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk '/Apple Development/ { print $2 }' | sort | head -1)}"
if [ -n "$IDENTITY" ] && codesign --force --deep --sign "$IDENTITY" "$APP" 2>/dev/null; then
  SIGNER=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)
  ok "Ký bằng $SIGNER: quyền được giữ qua các lần build"
else
  codesign --force --deep --sign - "$APP" 2>/dev/null
  warn "Ký tạm (không có chứng chỉ Apple Development): sau mỗi lần build phải cấp lại quyền Trợ năng"
fi
codesign --verify --deep --strict "$APP" 2>/dev/null || fail "Chữ ký của MrTV.app không hợp lệ"
ok "Chữ ký hợp lệ"
"$APP/Contents/MacOS/MrTV" --self-test 2>&1 | sed 's/^/  ✓ /' \
  || fail "MrTV.app không mở được. Xem lỗi ở trên, hoặc báo cáo trong Console › Crash Reports"
"$APP/Contents/Library/Input Methods/MrTVInput.app/Contents/MacOS/MrTVInput" --self-test 2>&1 | sed 's/^/  ✓ /' \
  || fail "Bộ gõ đi kèm không mở được"
