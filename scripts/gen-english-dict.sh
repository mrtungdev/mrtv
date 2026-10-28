#!/bin/zsh
# Tạo lại từ điển tiếng Anh ẩn của lõi gõ (core/mrtv-core/data/english-dict.txt) từ SCOWL.
#   scripts/gen-english-dict.sh
#
# Nguồn: English Speller Database (SCOWL) của Kevin Atkinson, https://wordlist.aspell.net,
# cỡ 35 (từ thông dụng), chính tả Mỹ. Chỉ giữ chữ thường a–z dài 2–20 ký tự.
# Lõi chỉ dùng từ điển này khi kết thúc từ, để biết có nên trả lại đúng phím đã gõ hay không.
set -euo pipefail
source "${0:A:h}/lib.sh"
reject_args "scripts/gen-english-dict.sh" "$@"

URL="https://app.aspell.net/create?max_size=35&spelling=US&max_variant=0&diacritic=strip&special=hacker&download=wordlist&encoding=utf-8&format=inline"
OUT="$ROOT/core/mrtv-core/data/english-dict.txt"

# Từ hiếm trùng với chữ ra khi huỷ dấu một từ thông dụng ("pass" → "pas"): bỏ đi để từ thông dụng thắng.
EXCLUDE=(pas)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

step "Tải SCOWL cỡ 35"
curl -fsSL -m 120 -o "$TMP/scowl.txt" "$URL" || fail "Không tải được $URL"
grep -q '^---$' "$TMP/scowl.txt" || fail "Tệp tải về không đúng dạng (thiếu dòng ---)."

revision="$(grep -m1 '^ESDB Git Revision:' "$TMP/scowl.txt" || true)"
sed '1,/^---$/d' "$TMP/scowl.txt" | grep -E '^[a-z]{2,20}$' | sort -u > "$TMP/words.txt"
for w in $EXCLUDE; do
  grep -vx -- "$w" "$TMP/words.txt" > "$TMP/next.txt" || true
  mv "$TMP/next.txt" "$TMP/words.txt"
done
count=$(wc -l < "$TMP/words.txt" | tr -d ' ')
(( count > 10000 )) || fail "Chỉ có $count từ, có gì đó không ổn."

{
  print -r -- "# Từ điển tiếng Anh ẩn của Mr TV, tạo bằng scripts/gen-english-dict.sh. Đừng sửa tay."
  print -r -- "# Nguồn: English Speller Database (SCOWL), https://wordlist.aspell.net, cỡ 35, chính tả Mỹ."
  [[ -n "$revision" ]] && print -r -- "# $revision"
  print -r -- "#"
  # Lời ghi bản quyền phải đi kèm mọi bản sao danh sách.
  sed -n '/^Copyright/,/^---$/p' "$TMP/scowl.txt" | sed '$d' | sed 's/^/# /; s/[[:space:]]*$//'
  cat "$TMP/words.txt"
} > "$OUT"

ok "$count từ → ${OUT#$ROOT/}"
