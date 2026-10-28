#!/bin/zsh
# Cài công cụ build một lần trên máy mới: Rust (qua rustup) và XcodeGen. Cần Homebrew và Xcode.
#   scripts/bootstrap.sh
set -euo pipefail
source "${0:A:h}/lib.sh"
reject_args "scripts/bootstrap.sh" "$@"

command -v brew >/dev/null || fail "Chưa có Homebrew. Cài theo hướng dẫn ở https://brew.sh rồi chạy lại."
xcode-select -p >/dev/null 2>&1 || fail "Chưa có Xcode. Cài Xcode 27 từ App Store rồi chạy lại."

step "Cài rustup và XcodeGen"
brew list rustup >/dev/null 2>&1 || brew install rustup
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
ok "Homebrew"

step "Cài Rust"
rustup default stable >/dev/null
rustup target add aarch64-apple-darwin x86_64-apple-darwin >/dev/null
rustup component add clippy rustfmt >/dev/null
ok "$(rustc --version)"

step "Xong"
note "Các script tự tìm Rust, không cần sửa ~/.zshrc."
note "Muốn gọi cargo trực tiếp thì thêm vào ~/.zshrc: export PATH=\"/opt/homebrew/opt/rustup/bin:\$PATH\""
note "Bước tiếp: scripts/check.sh"
