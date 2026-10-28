# Thay đổi

Mọi thay đổi người dùng thấy được đều ghi ở đây. Định dạng theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), số phiên bản theo [SemVer](https://semver.org/lang/vi/).

Khi phát hành, đổi "Chưa phát hành" thành `[phiên bản] - ngày`, thêm một mục "Chưa phát hành" trống ở trên và sửa link cuối tệp; `scripts/release.sh` lấy mục của phiên bản làm ghi chú phát hành.

## [Chưa phát hành]

### Sửa
- Tự cập nhật chạy từ bản này. Bản 0.1.0 không tự cài được bản mới: Mr TV báo có bản mới và mở trang tải, bạn tải về rồi cài đè lên.

## [0.1.0] - 2026-10-28

Bản đầu tiên.

### Thêm
- Lõi gõ viết bằng Rust: Telex, VNI, Telex đơn giản; đặt dấu tự do; đặt dấu kiểu mới (hoà) hoặc cũ (hòa). Gõ đúng mọi âm tiết tiếng Việt (hơn 17 000 âm tiết, mỗi âm tiết thử 6 cách gõ).
- Dấu mũ, dấu móc gõ sau cũng được: `vietej` → *việt*, `truongw` → *trương*, `muaw` → *mưa*; `uow` ra *ươ* ngay.
- Giữ nguyên từ tiếng Anh khi bấm dấu cách (`progress`, `class`, `pass`, `keep`), nhờ luật âm tiết và từ điển SCOWL có sẵn trong lõi; bấm `esc` để trả lại đúng phím vừa gõ.
- Bộ gõ chuẩn của macOS: gõ không gạch chân ở ứng dụng của Apple, chữ đang soạn ở ứng dụng khác.
- Gõ đè cho Chrome, VS Code, Slack, Zalo, Terminal, JetBrains, Claude, Sublime Text…, chọn riêng cho từng ứng dụng.
- Nhớ Việt/Anh theo từng ứng dụng; bấm `fn` để đổi.
- Gõ tắt theo chữ hoa/thường.
- Sửa dấu từ đã gõ: đặt con trỏ ngay sau từ (bấm chuột, phím mũi tên hay xoá lùi về) rồi gõ dấu, *Viêt* thêm `j` thành *Việt*.
- Bảng lệnh (⌥⌥) chạy việc trên chữ đang bôi đen và thay thẳng vào đó: chuyển ngược, sửa chữ lỗi font (TCVN3, VIQR), sửa dấu bị tách, số thành chữ, bỏ dấu, VIẾT HOA. Không bôi đen thì chạy trên chữ vừa chép.
- Hướng dẫn ngay trong bảng lệnh (⌥⌥ rồi gõ `?`); mở bảng lệnh khi chưa có chữ là thấy mọi phím đang dùng.
- Phím `fn` và `⌥⌥` chỉ cần quyền Trợ năng.
- Cài đặt: tìm theo từng cài đặt (không dấu cũng được), mục Từ tiếng Anh dạng bảng, Gõ tắt sửa ngay trong Cài đặt, Phím tắt tự đặt và báo trùng.
- Màn Bắt đầu, mở khi bật máy, ẩn/hiện biểu tượng trên thanh menu.
- Chạy từ macOS 12, cả máy Intel lẫn Apple silicon.

[Chưa phát hành]: https://github.com/mrtungdev/mrtv/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mrtungdev/mrtv/releases/tag/v0.1.0
