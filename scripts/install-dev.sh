#!/bin/zsh
# Build bản Release và để MrTV.app ngay trong thư mục dự án. Bạn tự kéo vào thư mục Ứng dụng.
#   scripts/install-dev.sh
set -euo pipefail
source "${0:A:h}/lib.sh"
reject_args "scripts/install-dev.sh" "$@"

"$ROOT/scripts/build.sh"
step "Chép ra thư mục dự án"
rm -rf "$ROOT/MrTV.app"
cp -R "$ROOT/build/Release/MrTV.app" "$ROOT/MrTV.app"
ok "$ROOT/MrTV.app"
note "Tiếp theo: thoát Mr TV nếu đang chạy, kéo MrTV.app vào thư mục Ứng dụng (thay bản cũ), rồi mở."
note "Lần đầu mở, màn Bắt đầu sẽ cài bộ gõ và hỏi quyền; mọi bước cho phép đều do bạn bấm."
note "Máy có chứng chỉ Apple Development thì bản dev ký bằng nó: quyền Trợ năng được giữ qua các lần build."
note "Không có thì bản dev ký tạm: sau mỗi lần thay bản mới, phải bật lại quyền Trợ năng."
