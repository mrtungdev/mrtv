# Hàm dùng chung cho các script. Nạp bằng: source "${0:A:h}/lib.sh"

ROOT="${ROOT:-${0:A:h:h}}"
export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"
export MACOSX_DEPLOYMENT_TARGET=12.0

if [[ -t 1 ]]; then
  _B=$'\e[1m'; _G=$'\e[32m'; _R=$'\e[31m'; _Y=$'\e[33m'; _D=$'\e[2m'; _N=$'\e[0m'
else
  _B=""; _G=""; _R=""; _Y=""; _D=""; _N=""
fi

step() { print -r -- "${_B}▸ $*${_N}"; }
ok()   { print -r -- "  ${_G}✓${_N} $*"; }
warn() { print -r -- "  ${_Y}!${_N} $*"; }
fail() { print -r -- "  ${_R}✗ $*${_N}" >&2; exit 1; }
note() { print -r -- "  ${_D}$*${_N}"; }

# Báo rõ khi có tham số lạ (thường do dán cả phần chú thích "# ..." vào zsh).
reject_args() {
  local usage="$1"; shift
  (( $# == 0 )) && return 0
  print -r -- "${_R}Không hiểu tham số: $*${_N}" >&2
  print -r -- "Cách dùng: $usage" >&2
  [[ "$1" == "#"* ]] && print -r -- "Mẹo: zsh không bỏ qua phần sau dấu #; chỉ dán lệnh, đừng dán chú thích." >&2
  exit 2
}

# cargo test: đạt thì chỉ in dòng kết quả (thêm tiền tố $1), hỏng thì in đủ để thấy ca nào hỏng.
cargo_test() {
  local prefix="$1"; shift
  local log="$ROOT/build/cargo-test.log"
  mkdir -p "$ROOT/build"
  if cargo test --quiet "$@" >"$log" 2>&1; then
    { grep -E "^test result" "$log" || true; } | grep -v " 0 passed" | sed "s/^/  $prefix/"
  else
    cat "$log" >&2
    fail "Bài thử lõi Rust hỏng (xem ở trên)."
  fi
}

# xcodebuild in rất nhiều dòng; chỉ giữ lỗi, cảnh báo của mã nguồn và kết quả.
xcb() {
  local log="$ROOT/build/xcodebuild.log"
  mkdir -p "$ROOT/build"
  if xcodebuild -project "$ROOT/apple/MrTV.xcodeproj" -derivedDataPath "$ROOT/build/DerivedData" \
       -destination "platform=macOS,arch=$(uname -m)" "$@" >"$log" 2>&1; then
    { grep -E "^[[:space:]]+Executed [0-9]+ tests" "$log" || true; } | tail -1 | sed 's/^[[:space:]]*/  /'
    { grep -E "\*\* (BUILD|TEST) SUCCEEDED" "$log" || true; } | tail -1 | sed 's/^/  /'
  else
    grep -E "error:|\*\* (BUILD|TEST) FAILED|Test Case .* failed" "$log" | sort -u | head -40 >&2
    fail "xcodebuild lỗi. Xem đủ ở build/xcodebuild.log"
  fi
}
