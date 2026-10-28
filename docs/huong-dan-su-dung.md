# Hướng dẫn sử dụng Mr TV

Tài liệu này dành cho người dùng. Muốn build hoặc đóng góp mã, xem [CONTRIBUTING.md](../CONTRIBUTING.md).

- [1. Cài đặt lần đầu](#1-cài-đặt-lần-đầu)
- [2. Gõ tiếng Việt](#2-gõ-tiếng-việt)
- [3. Đổi Việt ⇄ Anh](#3-đổi-việt--anh)
- [4. Bảng lệnh](#4-bảng-lệnh)
- [5. Gõ tắt](#5-gõ-tắt)
- [6. Theo từng ứng dụng](#6-theo-từng-ứng-dụng)
- [7. Hướng dẫn trong ứng dụng](#7-hướng-dẫn-trong-ứng-dụng)
- [8. Cài đặt](#8-cài-đặt)
- [9. Khi có sự cố](#9-khi-có-sự-cố)

## 1. Cài đặt lần đầu

Sau khi kéo Mr TV vào thư mục Ứng dụng và mở lên, màn **Bắt đầu** dẫn bạn qua 3 bước. Đóng cửa sổ lúc nào cũng được: việc còn thiếu sẽ được nhắc ở đầu cửa sổ Cài đặt và trong menu Mr TV.

| Bước | Bạn làm gì | Vì sao |
|---|---|---|
| 1. Kiểu gõ | Chọn Telex, Telex đơn giản hoặc VNI, chọn cách đặt dấu, rồi gõ thử `tieesng Vieejt` | Phải ra **tiếng Việt**. Đổi lại được ở Cài đặt › Gõ chữ |
| 2. Bật Mr TV | Bấm **Dùng bộ gõ Mr TV** (bấm **Cho phép** khi macOS hỏi), rồi **Cấp quyền…** Trợ năng | Từ macOS 12, mọi bộ gõ mới đều phải được người dùng cho phép. Xem [Quyền](#quyền) |
| 3. Hai phím | Nhớ `fn` (đổi Việt ⇄ Anh) và `⌥⌥` (mở Bảng lệnh). Nên đặt "Nhấn phím 🌐 để: Không làm gì" | Để `fn` chỉ đổi Việt ⇄ Anh, không mở bảng biểu tượng cảm xúc |

Ở bước 2, mỗi dòng tự chuyển sang **Xong** khi bạn bật trong Cài đặt hệ thống, không cần mở lại Mr TV.

### Quyền

Xem và cấp quyền ở **Cài đặt › Chung › Quyền**.

| Quyền | Dùng để | Không có thì |
|---|---|---|
| Trợ năng | Gõ đè ở Chrome, VS Code, Terminal…; đọc chữ trước con trỏ để sửa dấu từ đã gõ; đọc và thay chữ bạn bôi đen; đặt nhãn Việt/Anh ngay dưới con trỏ chữ | Các ứng dụng đó dùng chữ gạch chân; bảng lệnh chỉ chạy trên chữ vừa chép |
| Giám sát đầu vào | Không cần khi đã có Trợ năng. Chỉ để nghe phím `fn` và `⌥⌥` khi chưa có Trợ năng | Đổi Việt/Anh bằng menu Mr TV thay vì phím |

Mr TV không lưu và không gửi đi chữ đọc được qua các quyền này.

## 2. Gõ tiếng Việt

### Telex

| Phím | Ra | Ví dụ |
|---|---|---|
| `s` `f` `r` `x` `j` | sắc, huyền, hỏi, ngã, nặng | `tieesng` → tiếng, `hoaf` → hoà |
| `z` | bỏ dấu thanh | `asz` → a |
| `aa` `ee` `oo` | â ê ô | `caan` → cân |
| `aw` | ă | `bawns` → bắn |
| `ow` `uw` | ơ ư | `mow` → mơ, `tuw` → tư |
| `w` đứng một mình | ư | `tw` → tư (Telex đơn giản thì không) |
| `uow` | ươ | `dduowcj` → được, `nguowif` → người |
| `dd` | đ | `ddi` → đi |

### VNI

| Phím | Ra |
|---|---|
| `1` `2` `3` `4` `5` | sắc, huyền, hỏi, ngã, nặng |
| `0` | bỏ dấu thanh |
| `6` | â ê ô |
| `7` | ơ ư (`uo7` → ươ) |
| `8` | ă |
| `9` | đ |

Ví dụ: `Vie65t` → Việt, `d9u7o7c5` → được.

### Đặt dấu thanh

- **Gõ thanh ở đâu cũng được**: `tieengs`, `tieesng` đều ra *tiếng*. Mr TV tự đặt thanh đúng chỗ.
- **Dấu mũ, dấu móc gõ sau cũng được**: `vietej`, `vieetj` → *việt*; `truongw` → *trương*; `nguoiwf` → *người*.
- **Kiểu mới hay kiểu cũ** (Cài đặt › Gõ chữ › Đặt dấu): *hoà, hoè, thuỷ* hoặc *hòa, hòe, thủy*. Chỉ khác ở "oa", "oe", "uy" khi không có âm cuối.
- **Bấm phím dấu hai lần** để bỏ dấu và giữ chữ: `ass` → *as*, `aaa` → *aa*, `ww` → *w*.
- **Quên dấu ở từ trước?** Đặt con trỏ ngay sau từ đó rồi gõ dấu:
  - xoá lùi về: gõ *Tiêng*, cách, gõ tiếp vài chữ, xoá lùi về sau chữ *g* rồi bấm `s` là ra *Tiếng*;
  - hoặc bấm chuột, phím mũi tên tới ngay sau từ: *Viêt* thêm `j` thành *Việt*, *ban* thêm `j` thành *bạn*.
  - con trỏ nằm giữa một từ (ngay sau nó còn chữ) thì Mr TV gõ như chữ mới, không đụng vào từ đang có. Ở ứng dụng gõ đè (Chrome, VS Code…) cần quyền Trợ năng để đọc chữ trước con trỏ.
- **Gõ tiếp từ cũ**: xoá lùi qua dấu cách hay dấu câu là quay lại từ trước, gõ tiếp như đang gõ dở: *hoa,* xoá dấu phẩy rồi bấm `f` → *hoà*; *viêt* xoá chữ *t*, gõ `n` → *viên*.
- **ươ gõ một lần là ra**: `uow` → *ươ*, `nguowi` → *ngươi*. Riêng *thuở, huơ, khuơ* giữ "uơ" cho đúng chính tả.

Các cách trên luôn bật, không cần chỉnh gì.

### Từ tiếng Anh

- Chữ không thể là tiếng Việt thì Mr TV tự trả lại phím gốc ngay khi gõ: `good`, `book`, `web`, `facebook`.
- Khi bạn bấm dấu cách, chữ không phải âm tiết tiếng Việt trọn vẹn được trả lại đúng phím đã gõ: `progress`, `class`, `sure`, `tomorrow`. Từ tiếng Anh thông dụng cũng vậy, kể cả khi có chữ đôi hay chữ ra chỉ thiếu dấu thanh: `pass`, `error`, `keep`, `photo`. Bật/tắt ở **Cài đặt › Gõ chữ › Giữ nguyên từ tiếng Anh**.
- Gõ đôi phím dấu vẫn huỷ dấu như Telex: `ass` → *as*, `usser` → *user*, `wwindows` → *windows*.
- Từ nào vẫn bị biến đổi (ví dụ `test` → *tét*, vì *tét* cũng là chữ tiếng Việt): bấm `esc` ngay sau từ đó để lấy lại đúng phím đã gõ.
- Từ hay dùng thì thêm vào **Cài đặt › Gõ chữ › Sửa danh sách…**. Ở đó cũng tắt được từ có sẵn mà bạn muốn gõ thành tiếng Việt; xoá nhầm thì bấm **Hoàn tác**.

## 3. Đổi Việt ⇄ Anh

- Bấm `fn` để đổi, hoặc chọn **Tiếng Việt** / **Tiếng Anh** trong menu Mr TV. Biểu tượng trên thanh menu đổi giữa **V** (ô đặc) và **E** (ô viền).
- Mr TV **nhớ chế độ riêng cho từng ứng dụng**: Slack tiếng Việt, VS Code tiếng Anh… Tắt ở **Cài đặt › Ứng dụng › Nhớ Việt/Anh theo ứng dụng** nếu muốn dùng chung một chế độ.
- Nhãn nhỏ "V Tiếng Việt · Chrome" hiện ngay dưới con trỏ chữ khoảng một giây mỗi khi đổi. Không đọc được vị trí con trỏ thì nhãn hiện giữa cửa sổ đang dùng. Tắt ở **Cài đặt › Chung**.
- Đổi `fn` sang phím khác ở **Cài đặt › Phím**.

## 4. Bảng lệnh

Bôi đen chữ (bằng chuột hoặc Shift + mũi tên) rồi chạm `⌥⌥` (Phím Mr TV): bảng lệnh mở ra với tối đa hai việc hợp nhất cho đoạn đó ở trên, rồi mọi việc khác theo nhóm. Chọn bằng `↑↓` rồi `↩`, hoặc gõ tên để tìm (không dấu cũng được). Bên phải là kết quả xem trước. Kết quả thay thẳng vào chữ đang bôi đen; `⌘Z` để hoàn tác.

| Bạn bôi đen | Việc gợi ý đầu tiên |
|---|---|
| `tooi ddang` (lỡ gõ ở chế độ Anh) | Chuyển ngược → *tôi đang* |
| `ViÖt Nam` (chữ lỗi font TCVN3) | Sửa chữ lỗi font → *Việt Nam* |
| Chữ dán từ máy khác bị tách dấu | Sửa dấu bị tách |
| `1500000` | Số thành chữ → *một triệu năm trăm nghìn* |
| Chữ có dấu | Bỏ dấu |

Các việc khác: VIẾT HOA, viết thường, Hoa Đầu Từ, Đường dẫn không dấu (`Báo cáo quý 3` → `bao-cao-quy-3`), Từ VIQR sang Unicode. Số thành chữ chỉ nhận số nguyên; số lẻ như `1,5` không được đổi.

- **Không bôi đen gì**: việc chạy trên **chữ vừa chép** (clipboard) và chép kết quả lại vào clipboard, rồi bạn dán (`⌘V`).
- **Chưa có chữ nào**: bảng hiện các phím đang dùng và vài gõ tắt của bạn.
- **Gõ `?`**: xem hướng dẫn (mục 7).
- Đóng bảng bằng `esc` hoặc bấm ra ngoài. Mở bảng không cần phím: menu Mr TV › **Bảng lệnh…**.

## 5. Gõ tắt

Mở **Cài đặt › Gõ tắt** (hoặc menu Mr TV › **Gõ tắt…**). Gõ chữ tắt (ví dụ `ksao`) và câu đầy đủ ở dòng cuối bảng, bấm **Thêm**. Dùng được ngay, không cần tệp hay nạp lại.

- **Sửa**: bấm đúp một dòng.
- **Xoá**: chọn dòng rồi bấm **−**. Xoá nhầm thì bấm **Hoàn tác** ngay bên cạnh.
- **Tìm**: ô tìm phía trên bảng, gõ không dấu cũng được.
- Chưa có gõ tắt nào thì bấm **Thêm 3 mẫu** để bắt đầu rồi sửa lại cho hợp với bạn.

Chữ tắt chỉ gồm chữ không dấu và số, tối đa 20 ký tự. Gõ chữ tắt rồi bấm dấu cách (hoặc dấu câu). Chữ hoa đi theo cách gõ: `ksao` → *Không sao…*, `Ksao` → *Không sao…*, `KSAO` → *KHÔNG SAO…*. Muốn giữ đúng chữ tắt: bấm `esc` ngay sau khi câu hiện ra.

## 6. Theo từng ứng dụng

Mỗi ứng dụng có một **cách gõ** cho biết Mr TV đưa chữ vào bằng cách nào. Để **Tự động** là đủ: Mr TV chọn sẵn cho các ứng dụng quen thuộc. Chỉ đổi khi một ứng dụng gõ sai dấu, ở **Cài đặt › Ứng dụng**, hoặc nhanh hơn ở menu Mr TV › **Cách gõ trong <ứng dụng>**.

| Cách | Tự động dùng cho | Đặc điểm |
|---|---|---|
| **Gõ chuẩn** | Ứng dụng của Apple: Ghi chú, Mail, Pages, Safari, Xcode, TextEdit | Không gạch chân |
| **Gõ đè** | Chrome, Edge, Arc, VS Code, Cursor, Slack, Zalo, Notion, Word, Excel, Terminal, iTerm2, JetBrains… và ứng dụng chưa có trong danh sách | Xoá rồi gõ lại, không gạch chân. Cần quyền Trợ năng |
| **Chữ gạch chân** | Spotlight; mọi ứng dụng gõ đè khi chưa có quyền Trợ năng | Không bao giờ mất chữ; ứng dụng vẽ gạch chân hay khung quanh chữ đang gõ |

Bảng ở Cài đặt › Ứng dụng có ứng dụng vừa dùng, ứng dụng bạn đã đổi (có chấm **đã đổi**) và ứng dụng bạn tự thêm bằng nút **+**. Mỗi dòng chọn được chế độ Việt/Anh nhớ cho ứng dụng đó và cách gõ. **Về Tự động** bỏ lựa chọn riêng của dòng đang chọn.

Thấy một ứng dụng gõ sai? Thử đổi cách khác. Cách nào chạy tốt, hãy [báo cho Mr TV](https://github.com/mrtungdev/mrtv/issues/new/choose) để thêm vào hồ sơ mặc định cho mọi người.

## 7. Hướng dẫn trong ứng dụng

- **Hướng dẫn**: chạm `⌥⌥` rồi gõ `?`, hoặc menu Mr TV › **Hướng dẫn**. Có 8 bài: không gõ được tiếng Việt, đổi Việt ⇄ Anh, bảng lệnh, sửa dấu một từ đã gõ, lỡ gõ khi đang ở tiếng Anh, giữ nguyên từ tiếng Anh, ô mật khẩu chặn bộ gõ, mất quyền sau khi cập nhật macOS. Gõ tiếp để tìm (`?mat quyen`), nhiều bài có nút làm theo ngay.
- **Phím đang dùng**: mở Bảng lệnh khi chưa có chữ nào.
- Phím trong mọi bài hướng dẫn là phím bạn đã đặt ở **Cài đặt › Phím**.

## 8. Cài đặt

Mở bằng menu Mr TV › **Cài đặt…** (`⌘,`). Ô **Tìm** ở thanh bên tìm được từng cài đặt, gõ không dấu cũng được: `gach chan`, `fn`, `go tat`. Khi Mr TV chưa gõ được (chưa dùng bộ gõ Mr TV, thiếu quyền, ô mật khẩu đang chặn), đầu mọi trang có một băng báo kèm nút sửa.

| Mục | Có gì |
|---|---|
| Gõ chữ | Kiểu gõ, đặt dấu, giữ nguyên từ tiếng Anh và danh sách từ |
| Gõ tắt | Bật gõ tắt; thêm, sửa, xoá, tìm gõ tắt |
| Ứng dụng | Nhớ Việt/Anh theo ứng dụng; cách gõ cho từng ứng dụng |
| Phím | Phím đổi Việt ⇄ Anh (fn, ⌃⇧, ⌘⇧, ⇧⇧ hoặc tổ hợp tự đặt) và Phím Mr TV (⌥⌥, ⌃⌃, ⌘⌘, ⇧⇧ hoặc tổ hợp). Báo ngay khi trùng; lối mở cài đặt phím 🌐 của macOS |
| Chung | Mở khi bật máy, biểu tượng trên thanh menu, nhãn Việt/Anh; Quyền (bộ gõ Mr TV, Trợ năng, Giám sát đầu vào); Riêng tư |

Phiên bản, mã nguồn, giấy phép: menu Mr TV › **Về Mr TV**.

Đã tắt biểu tượng trên thanh menu? Mở lại ứng dụng Mr TV trong thư mục Ứng dụng, hoặc chọn **Cài đặt Mr TV…** trong menu bộ gõ của macOS, là vào được Cài đặt.

## 9. Khi có sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Không gõ ra tiếng Việt | Thường do máy đang dùng bộ gõ khác (ABC, U.S.): bấm fn, hoặc menu Mr TV › Dùng bộ gõ Mr TV. Sau đó xem Cài đặt › Chung › Quyền: bộ gõ phải "Đang dùng", Trợ năng phải "Đã cấp" |
| Biểu tượng có viền đứt | Mr TV đang không gõ được ở đây. Mở menu Mr TV để xem lý do: chưa dùng bộ gõ Mr TV, hoặc một ứng dụng đang bật chế độ nhập bảo mật (Mr TV ghi tên ứng dụng đó). Với Terminal: bỏ chọn Terminal › Secure Keyboard Entry |
| Gạch chân hoặc khung quanh chữ đang gõ (Claude, Sublime, Chrome…) | Mr TV gõ đè cho các ứng dụng này, cần quyền Trợ năng: bấm Cấp quyền… ở Cài đặt › Chung › Quyền. Chưa có quyền thì Mr TV tạm dùng chữ gạch chân |
| Mất quyền sau khi cập nhật macOS | Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Trợ năng: tắt rồi bật lại Mr TV. Băng báo trong Cài đặt tự biến mất khi quyền đã có |
| `fn` mở bảng biểu tượng cảm xúc | Cài đặt hệ thống › Bàn phím › "Nhấn phím 🌐 để: Không làm gì" (Cài đặt › Phím có nút mở thẳng chỗ này) |
| Mất chữ, nhân đôi chữ ở một ứng dụng | Đổi cách gõ ở Cài đặt › Ứng dụng, rồi [báo lỗi](https://github.com/mrtungdev/mrtv/issues/new/choose) kèm tên ứng dụng và phiên bản |

Khi báo lỗi, **đừng dán chữ bạn đã gõ** nếu đó là nội dung riêng tư. Chỉ cần: tên ứng dụng, phiên bản ứng dụng, phiên bản macOS, cách gõ đang dùng, và các phím đã bấm (ví dụ `tieesng`).
