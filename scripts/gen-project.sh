#!/bin/zsh
# Sinh apple/MrTV.xcodeproj từ apple/project.yml. Đừng sửa tay tệp .xcodeproj.
#   scripts/gen-project.sh
set -euo pipefail
source "${0:A:h}/lib.sh"
reject_args "scripts/gen-project.sh" "$@"

command -v xcodegen >/dev/null || fail "Chưa có XcodeGen. Chạy: scripts/bootstrap.sh"
[[ -d "$ROOT/Frameworks/MrTVCore.xcframework" ]] || "$ROOT/scripts/build-core.sh"
step "Sinh dự án Xcode"
cd "$ROOT/apple"
xcodegen generate --quiet
ok "apple/MrTV.xcodeproj"
