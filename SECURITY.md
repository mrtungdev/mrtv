# Bảo mật

Bộ gõ thấy mọi phím người dùng bấm, kể cả những gì riêng tư nhất. Mr TV coi bảo mật là việc quan trọng nhất.

## Mr TV cam kết

- Không gửi chữ người dùng gõ ra khỏi máy.
- Không lưu lại phím đã bấm. Chỉ lưu gõ tắt, cài đặt và các con số thống kê trên máy, không kèm chữ.
- Không ghi chữ người dùng gõ vào nhật ký hệ thống, kể cả trong bản debug.
- Kết nối mạng duy nhất là kiểm tra bản mới (chỉ gửi số phiên bản), và chỉ có khi bản phát hành có địa chỉ cập nhật.
- Mỗi tệp phát hành có mã SHA-256 để kiểm tra. Bản phát hành hiện chưa ký Developer ID và chưa công chứng với Apple (xem [Mở lần đầu](README.md#mở-lần-đầu)); khi dự án có tài khoản Apple Developer, bản phát hành sẽ được ký và công chứng.

## Báo lỗ hổng

**Đừng mở issue công khai.** Hãy báo riêng qua một trong hai cách:

- GitHub: tab **Security › Report a vulnerability** của kho mã nguồn (Private vulnerability reporting).
- Email: [hi@mrtung.dev](mailto:hi@mrtung.dev), tiêu đề bắt đầu bằng "[Bảo mật]"

Nên kèm: phiên bản Mr TV, phiên bản macOS, cách tái hiện, và mức ảnh hưởng bạn đánh giá. Đừng gửi chữ thật của ai đó; dùng chữ mẫu.

Người giữ dự án sẽ:

1. Xác nhận đã nhận trong vòng 3 ngày làm việc.
2. Đánh giá và báo hướng xử lý trong vòng 14 ngày.
3. Phát hành bản sửa, rồi công bố chi tiết sau khi phần lớn người dùng đã cập nhật, kèm ghi công người báo nếu bạn muốn.

## Phiên bản được hỗ trợ

Chỉ bản phát hành mới nhất được sửa lỗi bảo mật, nên hãy dùng bản mới nhất trên trang [Releases](https://github.com/mrtungdev/mrtv/releases).
