#!/bin/zsh
# Gỡ Mr TV khỏi máy: ứng dụng, bộ gõ, mục mở khi bật máy.
#   scripts/uninstall.sh          giữ lại gõ tắt và cài đặt của bạn
#   scripts/uninstall.sh --all    xoá luôn gõ tắt và cài đặt
set -euo pipefail
source "${0:A:h}/lib.sh"

ALL=0
if [[ "${1:-}" == "--all" ]]; then ALL=1; shift; fi
reject_args "scripts/uninstall.sh [--all]" "$@"

step "Tắt Mr TV"
osascript -e 'tell application id "dev.mrtung.mrtv" to quit' >/dev/null 2>&1 || true
pkill -x MrTVInput 2>/dev/null || true
ok "Đã tắt"

step "Gỡ ứng dụng và bộ gõ"
for p in "$HOME/Applications/MrTV.app" "/Applications/MrTV.app" "$HOME/Library/Input Methods/MrTVInput.app" \
         "$HOME/Library/LaunchAgents/dev.mrtung.mrtv.login.plist"; do
  if [[ -e "$p" ]]; then
    rm -rf "$p" && ok "Đã xoá $p"
  fi
done

if (( ALL )); then
  step "Xoá gõ tắt và cài đặt"
  rm -rf "$HOME/Library/Application Support/Mr TV"
  defaults delete dev.mrtung.mrtv >/dev/null 2>&1 || true
  defaults delete dev.mrtung.mrtv.shared >/dev/null 2>&1 || true
  ok "Đã xoá"
else
  note "Giữ lại gõ tắt ở ~/Library/Application Support/Mr TV. Xoá luôn: scripts/uninstall.sh --all"
fi
note "Mr TV có thể còn trong Cài đặt › Bàn phím › Nguồn nhập tới khi bạn đăng xuất; bấm dấu − để bỏ ngay."
