#!/bin/zsh
# Chạy toàn bộ bài thử: lõi Rust và logic gõ Swift.
#   scripts/test.sh
set -euo pipefail
source "${0:A:h}/lib.sh"
reject_args "scripts/test.sh" "$@"

step "Bài thử lõi Rust"
cd "$ROOT/core"
cargo_test "" --workspace
if arch -x86_64 /usr/bin/true 2>/dev/null; then
  cargo_test "x86_64: " -p mrtv-core --target x86_64-apple-darwin
else
  note "Bỏ qua bài thử bản Intel: máy chưa cài Rosetta (softwareupdate --install-rosetta)."
fi

"$ROOT/scripts/build-core.sh" debug
"$ROOT/scripts/gen-project.sh"
step "Bài thử Swift"
xcb -scheme MrTV -configuration Debug test
