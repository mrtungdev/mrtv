# Phát hành Mr TV

Dành cho người giữ dự án. Một bản phát hành gồm:

- `MrTV-<phiên bản>.dmg` để người dùng tải;
- `MrTV-<phiên bản>.zip` cho Sparkle;
- `SHA256SUMS.txt` để kiểm tra tệp tải về;
- `appcast.xml` để ứng dụng tự cập nhật;
- `mr-tv.rb` cho Homebrew.

Tất cả do `scripts/release.sh` (hoặc `make release`) tạo ra trong `dist/<phiên bản>/`.

Vì sao Mr TV phát hành qua GitHub thay cho App Store, cần tài khoản gì, và bản chưa công chứng thì người dùng mở thế nào: xem [phan-phoi-qua-github.md](phan-phoi-qua-github.md).

## Chuẩn bị một lần

| Cần | Để làm gì | Cách có |
|---|---|---|
| Chứng chỉ **Developer ID Application** | Ký để Gatekeeper cho mở | Tài khoản Apple Developer › Certificates. Cài vào Chuỗi khoá |
| Hồ sơ công chứng | Apple công chứng (notarize) bản build | Lệnh bên dưới |
| Khoá EdDSA của Sparkle | Ký bản cập nhật | Lệnh `generate_keys` bên dưới |
| GitHub CLI | Tạo bản phát hành | `brew install gh`, rồi `gh auth login` |
| Remote GitHub | Đường dẫn tải về, appcast | `git remote add origin https://github.com/mrtungdev/mrtv.git` (đã gắn sẵn) |

Lưu hồ sơ công chứng vào Chuỗi khoá (dùng mật khẩu riêng cho ứng dụng, tạo ở appleid.apple.com):

```bash
xcrun notarytool store-credentials mrtv-notary --apple-id "<email Apple ID>" --team-id "<TEAMID>"
```

Tạo khoá EdDSA cho Sparkle. Khoá riêng nằm trong Chuỗi khoá; `release.sh` tự lấy khoá công khai từ đó (`generate_keys -p`) để ghi vào ứng dụng và ký `appcast.xml`. Chạy sau khi đã build ít nhất một lần, để Sparkle có trong `build/`:

```bash
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

Sao lưu khoá riêng ra tệp, cất vào trình quản lý mật khẩu rồi xoá tệp. Mất khoá này thì người dùng không tự cập nhật được nữa:

```bash
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x ~/Desktop/mrtv-sparkle-private-key
```

Không có khoá thì `release.sh` không bật tự cập nhật cho bản đó (không đặt `SUFeedURL`), vì bản ký tạm chỉ có khoá EdDSA để Sparkle tin bản mới. Bản 0.1.0 ra đời như vậy, nên appcast của mọi bản sau chỉ báo cho nó "có bản mới" kèm nút mở trang tải (`--informational-update-versions "<2"` trong `release.sh`).

Đặt biến môi trường, ví dụ trong `~/.zshrc`:

```bash
export DEVELOPER_ID="Developer ID Application: Tên Của Bạn (TEAMID)"
export NOTARY_PROFILE="mrtv-notary"
```

`SPARKLE_PUBLIC_KEY` chỉ cần khi đóng gói ở máy không có khoá riêng trong Chuỗi khoá; có cả hai thì script kiểm tra chúng khớp nhau.

Thiếu biến nào thì `release.sh` bỏ qua bước đó và báo rõ, nên vẫn thử đóng gói được trên máy chưa có tài khoản Apple Developer. Bản đó ký tạm, chỉ dùng để thử.

## Các bước phát hành

1. **Ghi thay đổi.** Trong `CHANGELOG.md`, đổi mục "Chưa phát hành" thành `## [0.1.1] - <ngày>`, thêm một mục "Chưa phát hành" trống ở trên, và sửa hai dòng link cuối tệp. Script lấy đúng mục của phiên bản làm ghi chú phát hành (kèm vào appcast để hiện trong hộp thoại cập nhật).
2. **Commit** thay đổi đó. Script không đóng gói khi còn thay đổi chưa commit.
3. **Đóng gói thử**, kiểm tra kỹ trước khi đăng:

   ```bash
   make release VERSION=0.1.0
   ```

   Script ghi phiên bản vào `apple/project.yml` và `core/Cargo.toml`, rồi lần lượt: chạy `check.sh`, build bản universal, đặt địa chỉ cập nhật, ký, công chứng, đóng DMG và ZIP, tính SHA-256, viết ghi chú, appcast và Homebrew cask.
4. **Thử bản đóng gói** trên ít nhất một máy macOS 12 và một máy Intel. Xem [danh sách thử](#danh-sách-thử-trước-khi-đăng).
5. **Đăng bản nháp** lên GitHub Releases:

   ```bash
   make release VERSION=0.1.0 PUBLISH=1
   ```

   Script commit thay đổi phiên bản, gắn tag `v0.1.0`, đẩy lên GitHub và tạo **bản nháp** kèm các tệp. Không có gì được công bố cho tới khi bạn bấm **Publish release** trên GitHub. **Đừng đánh dấu Pre-release**: ứng dụng tìm `appcast.xml` ở bản mới nhất (`releases/latest`), mục này bỏ qua pre-release.

   Tag đẩy lên cũng chạy workflow Phát hành; thấy tag đã có bản phát hành, workflow chỉ đóng gói để kiểm tra rồi dừng.
6. **Cập nhật Homebrew:** chép `dist/0.1.0/mr-tv.rb` vào kho tap của dự án.

## Phát hành bằng GitHub Actions

Đẩy một tag `v*` thì `.github/workflows/release.yml` tự đóng gói và tạo bản nháp. Khai báo các bí mật này trong **Settings › Secrets and variables › Actions**:

| Bí mật | Nội dung |
|---|---|
| `DEVELOPER_ID_P12` | Chứng chỉ Developer ID xuất ra tệp .p12, mã hoá base64 |
| `DEVELOPER_ID_P12_PASSWORD` | Mật khẩu của tệp .p12 |
| `DEVELOPER_ID` | Tên chứng chỉ, ví dụ `Developer ID Application: Tên (TEAMID)` |
| `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` | Để công chứng |

Thiếu bí mật thì workflow vẫn chạy nhưng tạo bản ký tạm. Bản dựng trên CI **không bật tự cập nhật** và không có `appcast.xml`, vì khoá EdDSA riêng chỉ nằm trên máy người giữ dự án; bản phát hành chính thức nên làm từ máy bằng `make release … PUBLISH=1`.

## Số phiên bản

- Theo [SemVer](https://semver.org/lang/vi/): `1.2.3`; bản thử: `1.3.0-beta.1`.
- Số build (`CFBundleVersion`) là số commit trên nhánh hiện tại, luôn tăng. Sparkle và trình cài bộ gõ dựa vào số này để biết có bản mới.
- Bản thử là phiên bản có hậu tố `-beta.N`, đăng dạng pre-release. Sparkle không thấy pre-release, người thử tải tay.

## Danh sách thử trước khi đăng

- [ ] Cài mới từ DMG trên một máy chưa có Mr TV: màn Bắt đầu, cho phép bộ gõ, cấp quyền
- [ ] Cập nhật từ bản trước qua Sparkle: bộ gõ được cài lại, quyền còn nguyên
- [ ] macOS 12 (máy ảo hoặc máy thật) và bản macOS mới nhất
- [ ] Máy Intel và máy Apple silicon
- [ ] Gõ `tieesng Vieejt dduowcj nguowif` trong TextEdit, Safari, Chrome, VS Code, Terminal, Zalo
- [ ] `fn`, `⌥⌥` (có bôi đen, không bôi đen, và khi chưa chép chữ nào)
- [ ] Sửa dấu từ đã gõ: bấm chuột sau *Viêt* rồi gõ `j` → *Việt*; xoá lùi qua dấu cách rồi gõ dấu
- [ ] Ô mật khẩu: Mr TV tạm dừng và báo đúng
- [ ] `codesign --verify --deep --strict` và `spctl -a -vv` trên MrTV.app đều đạt (với bản đã ký)
