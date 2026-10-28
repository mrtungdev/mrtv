# Phân phối qua GitHub, không qua App Store

Mr TV phát hành trên [GitHub Releases](https://github.com/mrtungdev/mrtv/releases) (DMG, ZIP cho Sparkle, Homebrew), không lên Mac App Store. Tài liệu này nói cần gì để người dùng tải về là mở được, và chuyện gì xảy ra nếu chưa có tài khoản Apple Developer trả phí. Các bước đóng gói chi tiết ở [RELEASING.md](RELEASING.md).

## Vì sao không lên Mac App Store

Ứng dụng trên Mac App Store bắt buộc chạy trong App Sandbox. Mr TV cần đúng những thứ sandbox không cho:

- phát phím tổng hợp bằng event tap (gõ đè ở Chrome, VS Code, Terminal…);
- dùng quyền Trợ năng để đọc chữ trước con trỏ, đọc và thay chữ đang bôi đen ở ứng dụng khác;
- chép bộ gõ vào `~/Library/Input Methods` và đăng ký nó với hệ thống.

Phát hành ngoài App Store là cách Apple cho phép sẵn: ký bằng **Developer ID** rồi **công chứng** (notarize). Người dùng mở như ứng dụng tải từ App Store, chỉ thêm một câu hỏi "tải từ Internet, có mở không".

## Hai cách phát hành

| | Có Apple Developer Program | Chưa có tài khoản trả phí |
|---|---|---|
| Chi phí | 99 USD/năm | 0 |
| Ký | Developer ID Application | Ký tạm (ad-hoc) |
| Công chứng | Có | Không làm được |
| Người dùng mở lần đầu | Mở bình thường, macOS hỏi một lần | Bị chặn, phải tự mở khoá (xem [bên dưới](#hướng-dẫn-người-dùng-khi-bản-chưa-công-chứng)) |
| Quyền Trợ năng khi cập nhật | Giữ nguyên | Mất sau mỗi bản mới, phải bật lại |
| Tự cập nhật (Sparkle) | Chạy | Chạy, nhưng mỗi bản mới lại mất quyền Trợ năng |
| Homebrew | Được | Kho chính của Homebrew không nhận (xem [Homebrew](#homebrew)) |

**Nên dùng Developer ID** cho mọi bản đưa tới người khác. Ký tạm chỉ hợp để thử trên máy mình hoặc vài người quen biết rõ cách mở khoá.

Chứng chỉ **Apple Development** mà bản dev đang dùng (`make install`) không dùng để phát hành được: Gatekeeper không nhận và Apple không công chứng bản ký bằng nó. Nó chỉ giúp giữ quyền Trợ năng qua các lần build trên máy của bạn.

## Chuẩn bị (một lần)

1. **Tham gia Apple Developer Program** ở [developer.apple.com/programs](https://developer.apple.com/programs/): đăng ký cá nhân là đủ, Apple ID cần bật xác thực hai lớp. Đã là thành viên thì trang [Certificates](https://developer.apple.com/account/resources/certificates/list) có mục tạo **Developer ID Application**.
2. **Tạo chứng chỉ Developer ID Application:** Xcode › Settings › Accounts › chọn tài khoản › Manage Certificates › **+** › Developer ID Application. Xuất một bản `.p12` cất chỗ an toàn (cần cho GitHub Actions và khi đổi máy).
3. **Lưu hồ sơ công chứng** vào Chuỗi khoá, dùng mật khẩu riêng cho ứng dụng tạo ở [account.apple.com](https://account.apple.com):

   ```bash
   xcrun notarytool store-credentials mrtv-notary --apple-id "<email Apple ID>" --team-id "<TEAMID>"
   ```

4. **Tạo khoá EdDSA cho Sparkle** để ký bản cập nhật (lệnh `generate_keys`, xem [RELEASING.md](RELEASING.md#chuẩn-bị-một-lần)). Mất khoá riêng thì người dùng bản cũ không tự cập nhật lên được nữa, nên sao lưu nó.
5. **Đặt biến môi trường** `DEVELOPER_ID`, `NOTARY_PROFILE` như trong [RELEASING.md](RELEASING.md#chuẩn-bị-một-lần). Khoá công khai của Sparkle thì `release.sh` tự lấy từ Chuỗi khoá.
6. **Kho GitHub phải công khai.** Kho để **Private** thì người ngoài không tải được tệp trong Releases, Sparkle không đọc được `appcast.xml`, Homebrew không tải được DMG. Kiểm tra ở **Settings › General › Danger Zone › Change visibility** (hoặc đăng bản phát hành ở một kho công khai riêng).

## Mỗi lần phát hành

Đóng gói, ký, công chứng vào `dist/0.1.0/`:

```bash
make release VERSION=0.1.0
```

Rồi tạo bản nháp trên GitHub Releases:

```bash
make release VERSION=0.1.0 PUBLISH=1
```

`scripts/release.sh` ký từ trong ra ngoài (dịch vụ và framework Sparkle, bộ gõ `MrTVInput.app` nằm trong ứng dụng, rồi `MrTV.app`) với `--options runtime --timestamp`, công chứng ứng dụng, đóng DMG, công chứng DMG và dán vé (staple) vào cả hai. Vé đã dán nên máy không có mạng vẫn mở được.

Kiểm tra trước khi bấm **Publish release**:

```bash
spctl -a -vv -t exec build/Release/MrTV.app
```

Phải ra `accepted` và `source=Notarized Developer ID`. Kiểm tra vé đã dán:

```bash
xcrun stapler validate dist/0.1.0/MrTV-0.1.0.dmg
```

Rồi tải DMG từ trang Releases về một máy khác (để tệp có cờ "tải từ Internet") và mở thử: không được có hộp thoại "không thể xác minh nhà phát triển".

## Homebrew

`release.sh` tạo sẵn `mr-tv.rb` cho tap riêng của dự án. Từ Homebrew 5.0 (11/2025), kho cask chính chỉ nhận ứng dụng đã ký và công chứng, cờ `--no-quarantine` bị bỏ dần, và cask không qua được Gatekeeper bị gỡ từ tháng 9/2026. Bản chưa công chứng vẫn đặt được trong tap riêng, nhưng người dùng vẫn bị Gatekeeper chặn như khi tải DMG.

## Hướng dẫn người dùng khi bản chưa công chứng

Chỉ cần khi phát hành bản ký tạm. README có sẵn mục [Mở lần đầu](../README.md#mở-lần-đầu), và `release.sh` tự thêm cách mở vào ghi chú phát hành khi bản chưa công chứng. Chi tiết:

- **macOS 15 trở lên:** mở Mr TV một lần (macOS báo chặn, bấm Xong) → Cài đặt hệ thống › **Quyền riêng tư & Bảo mật** › kéo xuống phần Bảo mật › **Vẫn mở** → nhập mật khẩu. Từ macOS 15, Control-bấm › Mở không còn bỏ qua được bước này.
- **macOS 12–14:** Control-bấm (hoặc bấm chuột phải) vào Mr TV trong thư mục Ứng dụng › **Mở** › **Mở**.
- **Cách bằng Terminal** (mọi bản macOS), sau khi đã kéo Mr TV vào thư mục Ứng dụng:

  ```bash
  xattr -dr com.apple.quarantine /Applications/MrTV.app
  ```

- Nếu cài xong mà bộ gõ Mr TV không hiện trong danh sách nguồn nhập, bỏ cờ cho cả bộ gõ đã được chép ra:

  ```bash
  xattr -dr com.apple.quarantine ~/Library/Input\ Methods/MrTVInput.app
  ```

- **Sau mỗi bản cập nhật:** vào Quyền riêng tư & Bảo mật › Trợ năng, bỏ Mr TV khỏi danh sách rồi thêm lại, vì chữ ký tạm đổi theo từng bản.
- Kiểm tra tệp tải về khớp với `SHA256SUMS.txt` trên trang phát hành:

  ```bash
  shasum -a 256 ~/Downloads/MrTV-0.1.0.dmg
  ```

## Tham khảo

- [Living with(out) notarization](https://eclecticlight.co/2024/10/01/living-without-notarization/) và [Gatekeeper and notarization in Sequoia](https://eclecticlight.co/2024/08/10/gatekeeper-and-notarization-in-sequoia/) — The Eclectic Light Company
- [What Homebrew 5.0.0 means for your Mac fleet](https://workbrew.com/blog/what-homebrew-5-0-0-means-for-your-mac-fleet) — Workbrew
- [RELEASING.md](RELEASING.md): đóng gói, GitHub Actions, danh sách thử trước khi đăng
