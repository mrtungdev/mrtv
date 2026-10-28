#!/bin/zsh
# Kiểm tra trước khi gửi PR hoặc phát hành: công cụ trên máy, định dạng mã, clippy, toàn bộ bài thử.
#   scripts/check.sh            kiểm tra đủ
#   scripts/check.sh --env      chỉ kiểm tra công cụ trên máy
set -euo pipefail
source "${0:A:h}/lib.sh"

ENV_ONLY=0
if [[ "${1:-}" == "--env" ]]; then ENV_ONLY=1; shift; fi
reject_args "scripts/check.sh [--env]" "$@"

step "Công cụ trên máy"
MISSING=0
need() {
  local name="$1" cmd="$2" fix="$3"
  if eval "$cmd" >/dev/null 2>&1; then ok "$name"; else print -r -- "  ${_R}✗${_N} $name — $fix"; MISSING=1; fi
}
need "macOS $(sw_vers -productVersion)" "true" ""
need "Xcode ($(xcodebuild -version 2>/dev/null | head -1))" "xcodebuild -version" "cài Xcode 27 từ App Store"
need "Homebrew" "command -v brew" "cài ở https://brew.sh"
need "Rust ($(rustc --version 2>/dev/null || echo chưa có))" "command -v cargo" "chạy scripts/bootstrap.sh"
need "Rust cho Intel (x86_64)" "rustup target list --installed | grep -q x86_64-apple-darwin" "chạy scripts/bootstrap.sh"
need "rustfmt, clippy" "cargo fmt --version && cargo clippy --version" "chạy scripts/bootstrap.sh"
need "XcodeGen" "command -v xcodegen" "chạy scripts/bootstrap.sh"
if command -v gh >/dev/null; then ok "GitHub CLI (để phát hành)"; else note "Không có GitHub CLI: chỉ cần khi phát hành (brew install gh)"; fi
if arch -x86_64 /usr/bin/true 2>/dev/null; then ok "Rosetta (thử bản Intel)"; else note "Không có Rosetta: bỏ qua bài thử bản Intel"; fi
(( MISSING == 0 )) || fail "Thiếu công cụ, làm theo gợi ý ở trên rồi chạy lại."
(( ENV_ONLY == 1 )) && exit 0

step "Định dạng mã và clippy"
cd "$ROOT/core"
cargo fmt --all -- --check || fail "Mã Rust chưa định dạng. Chạy: (cd core && cargo fmt --all)"
ok "rustfmt"
cargo clippy --quiet --workspace --all-targets -- -D warnings || fail "clippy còn cảnh báo"
ok "clippy"

"$ROOT/scripts/test.sh"
step "Mọi thứ ổn"
