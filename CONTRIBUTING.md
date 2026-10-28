# Đóng góp cho Mr TV

Cảm ơn bạn muốn góp sức. Mr TV miễn phí và mã nguồn mở, sống nhờ cộng đồng. Tài liệu này giúp bạn từ lúc dựng máy tới lúc PR được nhận.

- [Không cần viết mã vẫn giúp được](#không-cần-viết-mã-vẫn-giúp-được)
- [Chuẩn bị máy](#chuẩn-bị-máy)
- [Các lệnh](#các-lệnh)
- [Mã nguồn nằm ở đâu](#mã-nguồn-nằm-ở-đâu)
- [Quy trình gửi thay đổi](#quy-trình-gửi-thay-đổi)
- [Việc hay gặp, từng bước](#việc-hay-gặp-từng-bước)
- [Quy ước](#quy-ước)
- [Riêng tư khi phát triển](#riêng-tư-khi-phát-triển)

## Không cần viết mã vẫn giúp được

| Cách | Làm thế nào |
|---|---|
| Báo lỗi gõ sai | [Mở issue "Báo lỗi"](https://github.com/mrtungdev/mrtv/issues/new/choose): tên ứng dụng, phiên bản, macOS, các phím đã bấm. Không cần dán chữ riêng tư |
| Đề xuất hồ sơ ứng dụng | Issue "Hồ sơ ứng dụng": ứng dụng nào, cách đưa chữ nào chạy tốt |
| Thêm ca thử | Một dòng `phím gõ<TAB>chữ phải ra` trong `core/mrtv-core/tests/data/telex.tsv` |
| Góp ý câu chữ | Câu nào khó hiểu, lẫn tiếng Anh: mở issue hoặc sửa thẳng |
| Thử bản mới | Build bản mới nhất từ `main` bằng `make install` (xem [Chuẩn bị máy](#chuẩn-bị-máy)) và báo lại |

## Chuẩn bị máy

Để build cần máy Apple silicon chạy macOS 26.6 trở lên, **Xcode 27** và [Homebrew](https://brew.sh) — đó là yêu cầu của Xcode 27. Ứng dụng build ra vẫn chạy được từ macOS 12, cả trên máy Intel.

Chạy lần lượt từng lệnh trong thư mục mã nguồn:

```bash
make bootstrap
```

```bash
make check
```

`make bootstrap` cài Rust (qua rustup, cả bản cho Intel) và XcodeGen. `make check` kiểm tra công cụ trên máy, định dạng mã, clippy và chạy toàn bộ bài thử. Thấy toàn dấu ✓ là máy đã sẵn sàng.

> Chỉ dán đúng lệnh vào Terminal. zsh mặc định không coi `#` là chú thích, nên nếu dán cả phần chú thích phía sau, script sẽ báo "Không hiểu tham số".

## Các lệnh

| Lệnh | Làm gì |
|---|---|
| `make` | Xem danh sách lệnh |
| `make check` | Kiểm tra công cụ, `cargo fmt --check`, `clippy -D warnings`, toàn bộ bài thử. **Chạy trước khi gửi PR** |
| `make test` | Chỉ chạy bài thử (Rust + Swift) |
| `make build` | Build bản Release universal vào `build/Release/MrTV.app` |
| `make debug` | Build bản Debug cho máy đang dùng |
| `make snapshot` | Chụp mọi màn (Cài đặt, Bắt đầu, bảng lệnh, nhãn Việt/Anh) ở chế độ sáng và tối vào `build/snapshots/`. Sửa giao diện xong thì chụp lại, so với canvas thiết kế |
| `make install` | Build bản Release, mở thử, để `MrTV.app` trong thư mục dự án để bạn kéo vào Ứng dụng |
| `make uninstall` | Gỡ khỏi máy (giữ gõ tắt) |
| `make release VERSION=0.1.0` | Đóng gói bản phát hành vào `dist/` — xem [docs/RELEASING.md](docs/RELEASING.md) |
| `make clean` | Xoá mọi thứ sinh ra khi build |

Mỗi lệnh `make` gọi một script trong `scripts/`; gọi thẳng script cũng được, ví dụ `scripts/build.sh debug`.

Làm việc trong Xcode: chạy `scripts/gen-project.sh` rồi mở `apple/MrTV.xcodeproj`. Tệp `.xcodeproj` được sinh từ `apple/project.yml`: muốn thêm tệp, đổi cài đặt build thì sửa `project.yml`, đừng sửa trong Xcode.

## Mã nguồn nằm ở đâu

```
core/
  mrtv-core/              Lõi gõ (Rust): không biết gì về macOS
    src/engine.rs           nhận phím, giữ từ đang gõ, trả về chỉnh sửa
    src/input.rs            luật phím Telex / VNI
    src/syllable.rs         âm tiết, đặt thanh, kiểm tra chữ còn là tiếng Việt
    src/text.rs, charset.rs, number.rs, macros.rs   công cụ chữ, bảng mã, đọc số, gõ tắt
    data/english-dict.txt   từ điển tiếng Anh ẩn (SCOWL), tạo lại bằng scripts/gen-english-dict.sh
    tests/data/*.tsv        ca thử vàng
  mrtv-ffi/               C ABI cho Swift; header sinh ra ở include/mrtv.h
apple/
  project.yml             cấu hình dự án Xcode (XcodeGen)
  Shared/                 dùng chung cho bộ gõ và ứng dụng: nối lõi, cài đặt chung, InputSession
  MrTVInput/              bộ gõ macOS (đường A, InputMethodKit)
  MrTV/                   ứng dụng trên thanh menu: đường B, bảng lệnh, Cài đặt, Bắt đầu
    Resources/actions.json  thẻ việc của bảng lệnh (và thanh gợi ý, đang tạm ngừng)
  Shared/Resources/app-profiles.json   hồ sơ ứng dụng
  Tests/                  bài thử Swift
scripts/                  bootstrap, check, test, build, release, install-dev, uninstall, make-icons, gen-english-dict
docs/                     tech stack, hướng dẫn sử dụng, phát hành
```

Vì sao chọn Rust, hai tiến trình, hai đường đưa chữ: [docs/tech-stack.md](docs/tech-stack.md).

## Quy trình gửi thay đổi

1. **Mở issue trước** nếu thay đổi lớn (tính năng mới, đổi cách gõ), để bàn hướng làm trước khi viết mã.
2. **Tạo nhánh** từ `main`, đặt tên ngắn gọn: `sua/mat-chu-chrome`, `them/ho-so-zalo`, `tai-lieu/huong-dan-vni`.
3. **Viết mã kèm bài thử.** Sửa lỗi gõ thì thêm ca thử tái hiện lỗi đó trước.
4. **Chạy `make check`**, tất cả phải ✓.
5. **Commit** theo [quy ước](#commit), rồi mở PR và điền mẫu có sẵn.
6. Người duyệt xem trong vài ngày. Thay đổi nhỏ (ca thử, hồ sơ ứng dụng, câu chữ) thường được nhận nhanh.

### Trước khi gửi PR

- [ ] `make check` toàn ✓
- [ ] Có bài thử cho thay đổi (lõi: ca thử TSV hoặc unit test; Swift: XCTest)
- [ ] Câu chữ hiện ra theo [bảng tên gọi](#tên-gọi-thống-nhất)
- [ ] Không ghi log, không lưu, không gửi chữ người dùng gõ
- [ ] Chạy được trên macOS 12: API mới hơn phải bọc trong `if #available`
- [ ] Đã cập nhật `CHANGELOG.md` mục "Chưa phát hành" nếu người dùng thấy được thay đổi

## Việc hay gặp, từng bước

### Thêm ca thử gõ

Mở `core/mrtv-core/tests/data/telex.tsv` (hoặc `vni.tsv`), thêm một dòng: phím gõ, phím Tab, chữ phải ra. Dấu `_` ở cuối nghĩa là dấu cách.

```
khuyur	khuỷu
good_	good_
```

Rồi chạy:

```bash
make test
```

Ca thử cũng tự kiểm tra chiều ngược lại: chữ phải ra, khi đổi thành phím rồi gõ lại, phải ra đúng chữ đó.

### Thêm hoặc sửa hồ sơ ứng dụng

1. Lấy mã ứng dụng (bundle ID), ví dụ của Zalo:

   ```bash
   osascript -e 'id of app "Zalo"'
   ```

2. Thêm vào `apple/Shared/Resources/app-profiles.json`:

   ```json
   { "bundleID": "com.vng.zalo", "name": "Zalo", "path": "tap", "delayMs": 10 }
   ```

   `path` là `direct` (gõ chuẩn, không gạch chân), `composing` (chữ đang soạn, an toàn nhất) hoặc `tap` (gõ đè). `delayMs` chỉ dùng cho `tap`: độ trễ giữa các phím tổng hợp.
3. Thử bằng `make install`, rồi kéo `MrTV.app` vào Ứng dụng. Gõ nhanh một đoạn dài, có xoá lùi, trong ô chat, ô tìm kiếm và ô có gợi ý tự động. Chọn cách cho **0 lần mất chữ**; nếu nhiều cách cùng đạt, chọn cách không gạch chân.
4. Ghi trong PR: phiên bản ứng dụng, phiên bản macOS, các cách đã thử.

### Thêm một việc cho thanh gợi ý và bảng lệnh

Thanh gợi ý đang tạm ngừng (`Features.quickBar = false` trong `AppModel.swift`): mã vẫn giữ, Phím Mr TV mở bảng lệnh thay cho nó. Việc mới vẫn thêm như dưới đây và hiện trong bảng lệnh.

Mỗi việc là một **thẻ 8 dòng** trong `apple/MrTV/Resources/actions.json`:

```json
{
  "id": "so-thanh-chu", "ten": "Số thành chữ", "nhom": "doi",
  "khi": ["is_number"], "chay": ["quy_tac"], "cong_cu": "numberWords",
  "ket_qua": "thay_chu", "hoan_tac": "cmd_z", "muc": "co_ban", "uu_tien": 94,
  "meo": "Viết số tiền bằng chữ cho hoá đơn: bôi đen số rồi bấm 1.",
  "bai": "phong-tap/so-thanh-chu"
}
```

| Trường | Ý nghĩa |
|---|---|
| `ten` | Động từ + điều được làm, tối đa 3 từ |
| `nhom` | `sua`, `viet`, `dich`, `doi` — quyết định màu |
| `khi` | Điều kiện để lên thanh gợi ý (xem `TextFacts` trong `ActionRegistry.swift`) |
| `chay` | `quy_tac`, `ai_tren_may`, `khoa_api` — luôn chọn cách rẻ nhất |
| `cong_cu` | Tên công cụ trong lõi (`TextTool`); việc mới thì thêm hàm vào `core/mrtv-core/src/text.rs` |
| `ket_qua`, `hoan_tac` | Thay chữ hay xem trước; luôn hoàn tác được bằng ⌘Z |
| `muc` | `co_ban` (lên thanh gợi ý), `nang_cao` (chỉ trong bảng lệnh) |
| `meo`, `bai` | Một câu mẹo và một bài 1 phút |

Việc mới vào **bảng lệnh trước** (`"muc": "nang_cao"`); chỉ lên thanh gợi ý khi đã chứng minh có ích. Thanh gợi ý luôn chỉ có 3 việc.

### Sửa lõi gõ (Rust)

- Đường gõ phím phải nhanh: không cấp phát bộ nhớ mới, không ghi log trong `Engine::process`. Đo bằng:

  ```bash
  cd core && cargo bench -p mrtv-core
  ```

- Lõi không được biết gì về macOS hay giao diện. Thứ gì phụ thuộc hệ điều hành thì để ở Swift.
- Mọi thay đổi ở `mrtv-ffi/src/lib.rs` làm đổi `include/mrtv.h`; chạy `scripts/build-core.sh` rồi build lại ứng dụng.

### Sửa giao diện (Swift)

- Chỉ dùng API có trên **macOS 12**. API mới hơn (SMAppService, Liquid Glass, Foundation Models) phải nằm trong `if #available`.
- Ứng dụng dùng Swift 6. Riêng target bộ gõ (`MrTVInput`) dùng Swift 5 vì InputMethodKit chưa có chú thích concurrency.
- Logic gõ của bộ gõ nằm ở `apple/Shared/InputSession.swift` để thử bằng XCTest; giữ `InputController` thật mỏng.
- Màu, font, bo góc lấy từ `apple/MrTV/Design/Design.swift` (nhận diện "Cực quang"), không viết mã màu rời.

## Quy ước

### Commit

- Viết tiếng Việt, bắt đầu bằng động từ, dòng đầu không quá 72 ký tự.
- Một commit một việc.

```
Sửa mất chữ khi gõ nhanh trong ô địa chỉ Chrome
Thêm hồ sơ ứng dụng cho Zalo
Thêm ca thử cho "khuỷu" và "ngoẻo"
```

### Định dạng mã

- Rust: `cargo fmt` và `cargo clippy -- -D warnings` (đã nằm trong `make check`).
- Swift: theo phong cách các tệp xung quanh; ghi chú bằng tiếng Việt, ngắn, giải thích *vì sao*.

### Tên gọi thống nhất

Một khái niệm, một tên, ở mọi chỗ người dùng nhìn thấy. Tên biến trong mã có thể là tiếng Anh.

| Dùng | Không dùng |
|---|---|
| Thanh gợi ý | popover, quick bar, thanh tiện ích |
| Việc | action, tiện ích, tác vụ |
| Bảng lệnh | command palette |
| Phím Mr TV (⌥⌥) | hotkey, phím nóng |
| Gõ tắt | macro, text expansion |
| Chuyển ngược | reverse, convert |
| Đổi dạng chữ | transform, format |
| Hồ sơ ứng dụng | app profile |
| Chế độ nhập bảo mật | Secure Input |
| Mẹo | tip, hint, gợi ý (khi nói về mẹo) |
| Khoá API | API key, token |

## Riêng tư khi phát triển

Mr TV thấy mọi phím người dùng bấm. Vì thế:

- **Không bao giờ** ghi log, lưu, hay gửi đi chữ người dùng gõ, kể cả trong bản debug.
- Kết nối mạng mới phải tắt sẵn, có câu giải thích cho người dùng, và được ghi vào mục Riêng tư của README cùng [SECURITY.md](SECURITY.md).
- Phát hiện lỗ hổng bảo mật: **đừng mở issue công khai**, làm theo [SECURITY.md](SECURITY.md).

Mọi người tham gia dự án theo [Quy tắc ứng xử](CODE_OF_CONDUCT.md).
