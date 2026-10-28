#!/bin/zsh
# Đóng gói một bản phát hành cho GitHub Releases.
#   scripts/release.sh 0.1.0                   kiểm tra, build, ký, đóng gói vào dist/0.1.0/
#   scripts/release.sh 0.1.0 --publish         làm như trên rồi tạo bản NHÁP trên GitHub Releases
# Tuỳ chọn thêm: --skip-checks (bỏ qua check.sh), --allow-dirty (thử khi còn thay đổi chưa commit).
#
# Biến môi trường, thiếu biến nào thì bỏ qua bước đó và báo rõ:
#   DEVELOPER_ID        "Developer ID Application: Tên (TEAMID)" để ký, Gatekeeper mới cho mở
#   NOTARY_PROFILE      hồ sơ công chứng đã lưu bằng: xcrun notarytool store-credentials <tên>
#   SPARKLE_PUBLIC_KEY  khoá công khai EdDSA của Sparkle. Bỏ trống thì lấy từ Chuỗi khoá (generate_keys -p).
#                       Có khoá thì bản này tự cập nhật; không có thì không đặt địa chỉ cập nhật.
set -euo pipefail
source "${0:A:h}/lib.sh"

USAGE="scripts/release.sh <phiên bản, ví dụ 0.1.0> [--publish] [--skip-checks] [--allow-dirty]"
VERSION="" PUBLISH=0 SKIP=0 DIRTY=0
for a in "$@"; do
  case "$a" in
    --publish) PUBLISH=1 ;;
    --skip-checks) SKIP=1 ;;
    --allow-dirty) DIRTY=1 ;;
    <->.<->.<->|<->.<->.<->-*) VERSION="$a" ;;
    *) reject_args "$USAGE" "$a" ;;
  esac
done
[[ -n "$VERSION" ]] || { print -r -- "Cách dùng: $USAGE" >&2; exit 2; }
(( PUBLISH && DIRTY )) && fail "--publish không đi cùng --allow-dirty: bản phát hành phải từ mã đã commit."

cd "$ROOT"
IS_GIT=0
git rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
REPO=""
if (( IS_GIT )); then
  url=$(git remote get-url origin 2>/dev/null || true)
  [[ "$url" =~ 'github\.com[:/]([^/]+/[^/.]+)' ]] && REPO="${match[1]}"
fi

step "Chuẩn bị bản $VERSION"
if (( IS_GIT && !DIRTY )) && [[ -n "$(git status --porcelain)" ]]; then
  fail "Còn thay đổi chưa commit. Commit trước, hoặc thêm --allow-dirty để thử đóng gói."
fi
BUILD_NUMBER=$( (( IS_GIT )) && git rev-list --count HEAD 2>/dev/null || date +%y%m%d%H%M )
sed -i '' -E "s/^(    MARKETING_VERSION: ).*/\1\"$VERSION\"/" apple/project.yml
sed -i '' -E "s/^(    CURRENT_PROJECT_VERSION: ).*/\1\"$BUILD_NUMBER\"/" apple/project.yml
perl -0pi -e "s/^version = \"[^\"]*\"/version = \"$VERSION\"/m" core/Cargo.toml
ok "Phiên bản $VERSION, số build $BUILD_NUMBER"
[[ -n "$REPO" ]] && ok "GitHub: $REPO" || warn "Chưa có remote GitHub: bỏ qua appcast, cask và --publish."

(( SKIP )) || "$ROOT/scripts/check.sh"
"$ROOT/scripts/build.sh" release
APP="$ROOT/build/Release/MrTV.app"
DIST="$ROOT/dist/$VERSION"
rm -rf "$DIST"
mkdir -p "$DIST"

step "Cấu hình cập nhật"
PLIST="$APP/Contents/Info.plist"
SPARKLE_BIN="$ROOT/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
# Không có khoá thì generate_keys vẫn in "ERROR: …" ra stdout: chỉ nhận khi chạy thành công và đúng dạng khoá.
KEYCHAIN_KEY=""
if out="$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null)" && [[ "$out" =~ '^[A-Za-z0-9+/]{43}=$' ]]; then
  KEYCHAIN_KEY="$out"
fi
if [[ -n "${SPARKLE_PUBLIC_KEY:-}" && -n "$KEYCHAIN_KEY" && "$SPARKLE_PUBLIC_KEY" != "$KEYCHAIN_KEY" ]]; then
  fail "SPARKLE_PUBLIC_KEY khác khoá trong Chuỗi khoá: bản cập nhật sẽ không qua được kiểm tra chữ ký."
fi
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-$KEYCHAIN_KEY}"
# Chỉ bật tự cập nhật khi ký được appcast. Có địa chỉ mà thiếu khoá thì Sparkle báo lỗi khi kiểm tra
# và không bao giờ cài được bản sau (bản ký tạm không có chữ ký Apple cố định để đối chiếu).
UPDATES=0
if [[ -n "$REPO" && -n "$SPARKLE_PUBLIC_KEY" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL https://github.com/$REPO/releases/latest/download/appcast.xml" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_KEY" "$PLIST"
  UPDATES=1
  ok "Tự cập nhật: SUFeedURL trỏ tới appcast của bản mới nhất, SUPublicEDKey"
else
  warn "Không bật tự cập nhật: cần remote GitHub và khoá EdDSA (chạy generate_keys của Sparkle một lần)"
fi

step "Ký ứng dụng"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  # Ký từ trong ra ngoài: dịch vụ của Sparkle, framework, bộ gõ, rồi ứng dụng.
  for p in "$SPARKLE"/XPCServices/*.xpc "$SPARKLE/Autoupdate" "$SPARKLE/Updater.app" \
           "$APP/Contents/Frameworks/Sparkle.framework" "$APP/Contents/Library/Input Methods/MrTVInput.app" "$APP"; do
    [[ -e "$p" ]] && codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID" "$p"
  done
  codesign --verify --deep --strict "$APP"
  ok "Developer ID"
else
  codesign --force --deep --sign - "$APP" 2>/dev/null
  warn "Chưa có DEVELOPER_ID: ký tạm (ad-hoc). Gatekeeper sẽ chặn khi người khác mở."
fi

if [[ -n "${DEVELOPER_ID:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
  step "Công chứng ứng dụng với Apple"
  ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
  xcrun notarytool submit "$DIST/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$DIST/notarize.zip"
  ok "Đã công chứng và gắn vé"
else
  warn "Chưa công chứng (cần DEVELOPER_ID và NOTARY_PROFILE)"
fi

step "Đóng gói"
ZIP="$DIST/MrTV-$VERSION.zip"
DMG="$DIST/MrTV-$VERSION.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Mr TV $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --timestamp --sign "$DEVELOPER_ID" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi
(cd "$DIST" && shasum -a 256 "MrTV-$VERSION.dmg" "MrTV-$VERSION.zip" > SHA256SUMS.txt)
ok "MrTV-$VERSION.dmg ($(du -h "$DMG" | cut -f1)), MrTV-$VERSION.zip, SHA256SUMS.txt"

step "Ghi chú phát hành"
NOTES="$DIST/RELEASE_NOTES.md"
awk -v v="$VERSION" '
  $0 ~ "^## \\[" v "\\]" {on=1; next}
  on && /^## \[/ {exit}
  on && /^\[[^]]+\]: / {exit}
  on {print}
' "$ROOT/CHANGELOG.md" > "$NOTES" || true
if [[ ! -s "$NOTES" ]]; then
  print -r -- "Mr TV $VERSION." > "$NOTES"
  warn "CHANGELOG.md chưa có mục [$VERSION]: dùng ghi chú mặc định"
else
  ok "Lấy từ CHANGELOG.md"
fi
cat >> "$NOTES" <<EOF

### Cài đặt
Tải \`MrTV-$VERSION.dmg\`, mở ra, kéo Mr TV vào thư mục Ứng dụng, rồi làm theo màn Bắt đầu. Cần macOS 12 trở lên, chạy cả máy Intel lẫn Apple silicon.
EOF
if [[ -z "${DEVELOPER_ID:-}" || -z "${NOTARY_PROFILE:-}" ]]; then
  cat >> "$NOTES" <<EOF

### Bản này chưa ký với Apple
macOS sẽ chặn ở lần mở đầu. Sau khi kéo Mr TV vào thư mục Ứng dụng, chạy trong Terminal:

\`\`\`bash
xattr -dr com.apple.quarantine /Applications/MrTV.app
\`\`\`

Cách khác, và việc cần làm sau mỗi lần cập nhật: xem [Mở lần đầu](https://github.com/${REPO:-mrtungdev/mrtv}#mở-lần-đầu).
EOF
  ok "Thêm cách mở bản chưa công chứng vào ghi chú"
fi

if (( UPDATES )); then
  step "Appcast"
  # generate_appcast không nhận hai tệp cùng phiên bản (DMG và ZIP): chỉ đưa ZIP, kèm ghi chú cùng tên.
  FEED_SRC=$(mktemp -d)
  cp "$ZIP" "$FEED_SRC/"
  cp "$NOTES" "$FEED_SRC/MrTV-$VERSION.md"
  # Bản 0.1.0 (số build 1) ra khi chưa có khoá EdDSA nên không tự cài được bản sau:
  # với nó, bản mới chỉ là thông báo kèm nút mở trang tải.
  "$SPARKLE_BIN/generate_appcast" --embed-release-notes \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --link "https://github.com/$REPO/releases/latest" --informational-update-versions "<2" \
    -o "$DIST/appcast.xml" "$FEED_SRC" \
    || fail "Không tạo được appcast.xml. Chuỗi khoá hỏi quyền cho generate_appcast thì bấm Cho phép."
  rm -rf "$FEED_SRC"
  ok "appcast.xml (đã ký EdDSA)"
fi

if [[ -n "$REPO" ]]; then
  step "Homebrew"
  SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
  cat > "$DIST/mr-tv.rb" <<EOF
cask "mr-tv" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$REPO/releases/download/v#{version}/MrTV-#{version}.dmg"
  name "Mr TV"
  desc "Bộ gõ tiếng Việt miễn phí, mã nguồn mở"
  homepage "https://github.com/$REPO"

  depends_on macos: ">= :monterey"

  app "MrTV.app"

  zap trash: [
    "~/Library/Application Support/Mr TV",
    "~/Library/Input Methods/MrTVInput.app",
    "~/Library/Preferences/dev.mrtung.mrtv.plist",
    "~/Library/Preferences/dev.mrtung.mrtv.shared.plist",
  ]
end
EOF
  ok "mr-tv.rb (Homebrew cask)"
fi

if (( PUBLISH )); then
  step "Đăng bản nháp lên GitHub Releases"
  command -v gh >/dev/null || fail "Cần GitHub CLI: brew install gh, rồi gh auth login"
  [[ -n "$REPO" ]] || fail "Chưa có remote GitHub (git remote add origin …)"
  if [[ -n "$(git status --porcelain apple/project.yml core/Cargo.toml core/Cargo.lock)" ]]; then
    git add apple/project.yml core/Cargo.toml core/Cargo.lock
    git commit -q -m "Phát hành $VERSION"
    ok "Commit đổi phiên bản"
  fi
  git rev-parse "v$VERSION" >/dev/null 2>&1 || git tag -a "v$VERSION" -m "Mr TV $VERSION"
  git push -q origin HEAD "v$VERSION"
  assets=("$DMG" "$ZIP" "$DIST/SHA256SUMS.txt")
  [[ -f "$DIST/appcast.xml" ]] && assets+=("$DIST/appcast.xml")
  gh release create "v$VERSION" "${assets[@]}" --repo "$REPO" --draft --title "Mr TV $VERSION" --notes-file "$NOTES"
  ok "Đã tạo bản nháp. Mở GitHub xem lại rồi bấm Publish release."
fi

step "Xong: dist/$VERSION/"
ls -1 "$DIST" | sed 's/^/  /'
