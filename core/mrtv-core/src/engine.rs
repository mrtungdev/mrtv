//! Bộ máy gõ: nhận từng phím, giữ từ đang gõ, trả về chỉnh sửa cần làm.
//!
//! Cách làm: lưu các phím đã bấm của từ hiện tại, sau mỗi phím chạy lại luật
//! từ đầu từ rồi so với chữ đang hiện để biết cần xoá mấy ký tự và chèn gì.
//! Từ tiếng Việt ngắn nên việc chạy lại chỉ tốn vài micro giây, đổi lại
//! luôn đúng kể cả khi đặt dấu tự do ("tiengs" → "tiếng").
//!
//! Sau khi khởi động, đường gõ phím không cấp phát bộ nhớ: mọi bộ đệm đều được dùng lại.

use std::collections::HashSet;

use unicode_segmentation::UnicodeSegmentation;

use crate::input::Word;
use crate::letters::{Letter, Mark, Tone};
use crate::macros::MacroTable;
pub use crate::syllable::ToneStyle;
use crate::syllable::{is_complete, is_valid_prefix, split, tone_index};

/// Từ dài hơn ngần này phím thì không biến đổi nữa (chắc chắn không phải tiếng Việt).
const MAX_WORD: usize = 24;
/// Số ký tự vừa gõ được nhớ lại, để xoá lùi về từ trước vẫn sửa tiếp được.
const HISTORY: usize = 64;

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum Method {
    #[default]
    Telex,
    /// Telex nhưng phím w đứng một mình không thành ư.
    SimpleTelex,
    Vni,
}

#[derive(Clone, Copy, Debug)]
pub struct Config {
    pub method: Method,
    pub tone_style: ToneStyle,
    /// Kết thúc từ mà chữ là từ tiếng Anh quen thuộc và không phải âm tiết tiếng Việt thì trả lại phím gốc.
    pub restore_english: bool,
    pub macros_enabled: bool,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            method: Method::Telex,
            tone_style: ToneStyle::New,
            restore_english: true,
            macros_enabled: true,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Key {
    Char(char),
    Backspace,
    Escape,
}

/// Kết quả của một phím.
///
/// Nếu `consumed` là false, phím được để đi tiếp như bình thường (sau khi áp chỉnh sửa, nếu có).
/// Nếu true, bộ gõ nuốt phím và tự xoá `backspaces` ký tự rồi chèn `Engine::insert()`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct Output {
    pub consumed: bool,
    pub backspaces: u32,
    /// Như `backspaces` nhưng tính theo đơn vị UTF-16 (emoji tính 2), cho nơi xoá theo khoảng
    /// `NSRange` thay vì bấm phím xoá. Chỉ khác `backspaces` khi có ký tự ngoài BMP, ví dụ trong gõ tắt.
    pub deleted_utf16: u32,
    /// Số lần bấm phím xoá để xoá đúng chừng đó chữ (đường gõ đè): một phím xoá xoá cả một cụm ký tự,
    /// nên emoji ghép như 👨‍👩‍👧‍👦 (7 ký tự) chỉ tính một lần.
    pub delete_keys: u32,
    pub insert_len: u32,
}

impl Output {
    pub const PASS: Output = Output {
        consumed: false,
        backspaces: 0,
        deleted_utf16: 0,
        delete_keys: 0,
        insert_len: 0,
    };

    pub fn has_edit(&self) -> bool {
        self.backspaces > 0 || self.insert_len > 0
    }
}

pub struct Engine {
    cfg: Config,
    /// Phím đã bấm trong từ hiện tại (hoặc chữ thô khi đã khoá).
    raw: Vec<char>,
    /// Chữ đang hiện là phím thô (từ chưa phải tiếng Việt). Xét lại sau mỗi phím: gõ thêm dấu
    /// có thể làm từ thành tiếng Việt ("viet" → "vietj" → "vietje" = "việt").
    locked: bool,
    /// Giữ phím thô cho tới hết từ: sau esc, từ quá dài, hoặc chữ không dựng lại được bằng phím.
    forced: bool,
    /// Chữ của từ hiện tại đang nằm trên màn hình.
    emitted: Vec<char>,
    next: Vec<char>,
    word: Word,
    display: Vec<Letter>,
    insert: Vec<u16>,
    word_utf16: Vec<u16>,
    macros: MacroTable,
    english: HashSet<String>,
    /// Từ có sẵn trong danh sách tiếng Anh mà người dùng đã tắt.
    english_off: HashSet<String>,
    exceptions: HashSet<String>,
    key_buf: String,
    /// Chữ đã gõ trước từ hiện tại (các từ và dấu cách, dấu câu), tính từ lần `reset` gần nhất.
    /// Xoá lùi qua dấu cách thì lấy lại từ trước đó: "Tiêng ⌫" rồi gõ "s" ra "Tiếng".
    history: Vec<char>,
    /// Vị trí trong `history` ngay sau từ vừa được trả lại phím gốc khi kết thúc từ ("moot"). Xoá lùi về
    /// đúng từ đó thì gõ tiếp vẫn xét lại, để thêm thanh được ("moot ⌫ j" → "một"); chữ có sẵn khác
    /// (con trỏ đặt sau "keep") thì vẫn giữ nguyên phím.
    restored_end: Option<usize>,
    /// Gõ tắt vừa bung ra: số ký tự cần xoá (câu + dấu cách) và chữ để gõ lại, cho phím esc ngay sau đó.
    undo_len: u32,
    /// `undo_len` tính theo đơn vị UTF-16 và theo số lần bấm phím xoá.
    undo_utf16: u32,
    undo_keys: u32,
    /// Chỗ ghép chữ tạm để đếm cụm ký tự, giữ lại cho khỏi cấp phát mỗi phím.
    scratch: String,
    undo: Vec<char>,
}

fn utf16_len(chars: &[char]) -> u32 {
    chars.iter().map(|c| c.len_utf16() as u32).sum()
}

/// Số ký tự của cụm ký tự cuối trong `chars`: một lần bấm phím xoá xoá cả cụm ("a" + dấu huyền
/// kết hợp, emoji ghép 👨‍👩‍👧‍👦).
fn last_cluster_len(scratch: &mut String, chars: &[char]) -> usize {
    match chars {
        [] => 0,
        // Hai ký tự cuối đều ASCII (trừ xuống dòng, "\r\n" là một cụm): ký tự cuối đứng riêng.
        [.., a, b] if a.is_ascii() && b.is_ascii() && *b != '\n' => 1,
        [b] if b.is_ascii() => 1,
        _ => {
            scratch.clear();
            scratch.extend(chars);
            scratch
                .graphemes(true)
                .next_back()
                .map_or(1, |g| g.chars().count())
        }
    }
}

/// Số cụm ký tự (grapheme) của `chars` rồi `last`: số lần bấm phím xoá để xoá hết chừng đó.
fn clusters(scratch: &mut String, chars: &[char], last: Option<char>) -> u32 {
    // Chữ trong từ đang gõ là chữ dựng sẵn, mỗi ký tự một cụm: khỏi ghép chuỗi.
    if last.is_none() && chars.iter().all(|c| c.is_ascii_alphanumeric()) {
        return chars.len() as u32;
    }
    scratch.clear();
    scratch.extend(chars);
    scratch.extend(last);
    scratch.graphemes(true).count() as u32
}

impl Default for Engine {
    fn default() -> Self {
        Engine::new(Config::default())
    }
}

impl Engine {
    pub fn new(cfg: Config) -> Engine {
        // Nạp sẵn từ điển ở đây, để phím đầu tiên không phải chờ.
        crate::text::english_dict();
        Engine {
            cfg,
            raw: Vec::with_capacity(32),
            locked: false,
            forced: false,
            emitted: Vec::with_capacity(32),
            next: Vec::with_capacity(32),
            word: Word::with_capacity(32),
            display: Vec::with_capacity(32),
            insert: Vec::with_capacity(64),
            word_utf16: Vec::with_capacity(64),
            macros: MacroTable::default(),
            english: crate::text::english_words(),
            english_off: HashSet::new(),
            exceptions: HashSet::new(),
            key_buf: String::with_capacity(32),
            history: Vec::with_capacity(HISTORY + 32),
            restored_end: None,
            undo_len: 0,
            undo_utf16: 0,
            undo_keys: 0,
            scratch: String::with_capacity(64),
            undo: Vec::with_capacity(32),
        }
    }

    pub fn config(&self) -> Config {
        self.cfg
    }

    pub fn set_config(&mut self, cfg: Config) {
        self.cfg = cfg;
        self.reset();
    }

    pub fn set_macros(&mut self, macros: MacroTable) {
        self.macros = macros;
    }

    /// Từ người dùng muốn luôn giữ nguyên phím gốc khi bấm dấu cách.
    pub fn set_exceptions<I: IntoIterator<Item = String>>(&mut self, words: I) {
        self.exceptions = words.into_iter().map(|w| w.to_lowercase()).collect();
    }

    /// Từ có sẵn trong danh sách tiếng Anh mà người dùng muốn gõ thành tiếng Việt như thường.
    pub fn set_english_off<I: IntoIterator<Item = String>>(&mut self, words: I) {
        self.english_off = words.into_iter().map(|w| w.to_lowercase()).collect();
    }

    /// Bỏ từ đang gõ và chữ đã nhớ, ví dụ khi người dùng bấm chuột hay phím mũi tên:
    /// con trỏ đã sang chỗ khác nên chữ đã nhớ không còn đúng. Quên luôn gõ tắt vừa bung,
    /// để esc ở chỗ mới không xoá nhầm chữ.
    pub fn reset(&mut self) {
        self.clear_word();
        self.history.clear();
        self.restored_end = None;
        self.undo_len = 0;
        self.undo_utf16 = 0;
        self.undo_keys = 0;
        self.undo.clear();
    }

    /// Con trỏ vừa tới cuối một từ có sẵn (bấm chuột, phím mũi tên, mở ô nhập): lấy từ đó làm từ đang gõ
    /// để sửa hay gõ nối tiếp. `before` là chữ ngay trước con trỏ (vài chục ký tự là đủ).
    /// Ví dụ: con trỏ sau "Viêt", gõ `j` ra "Việt"; sau "hoa", gõ `f` ra "hoà".
    pub fn resume(&mut self, before: &str) {
        self.reset();
        let chars: Vec<char> = before.chars().collect();
        let tail = chars
            .iter()
            .rev()
            .take_while(|c| c.is_alphanumeric())
            .count();
        if tail > MAX_WORD {
            return;
        }
        let split = chars.len() - tail;
        let head = &chars[split.saturating_sub(HISTORY)..split];
        // Nhớ cả phần trước từ, để xoá lùi qua dấu cách vẫn nối được về từ trước đó.
        self.remember(head);
        if tail > 0 {
            self.emitted.extend_from_slice(&chars[split..]);
            self.rebuild(false);
        }
    }

    /// Đang có từ dở (để nơi gọi biết có nên đọc chữ quanh con trỏ hay không).
    pub fn has_context(&self) -> bool {
        !self.emitted.is_empty() || !self.history.is_empty()
    }

    fn clear_word(&mut self) {
        self.raw.clear();
        self.emitted.clear();
        self.locked = false;
        self.forced = false;
        self.word.clear();
    }

    fn remember(&mut self, chars: &[char]) {
        self.history.extend_from_slice(chars);
        if self.history.len() > HISTORY {
            let extra = self.history.len() - HISTORY;
            self.history.drain(..extra);
            self.restored_end = self.restored_end.and_then(|e| e.checked_sub(extra));
        }
    }

    /// Chữ cần chèn của kết quả gần nhất, dạng UTF-16.
    pub fn insert(&self) -> &[u16] {
        &self.insert
    }

    pub fn insert_string(&self) -> String {
        String::from_utf16_lossy(&self.insert)
    }

    /// Từ đang gõ, dạng UTF-16 (dùng cho chữ đang soạn của bộ gõ chuẩn).
    pub fn current_word(&mut self) -> &[u16] {
        self.word_utf16.clear();
        let mut buf = [0u16; 2];
        for c in &self.emitted {
            self.word_utf16.extend_from_slice(c.encode_utf16(&mut buf));
        }
        &self.word_utf16
    }

    pub fn current_word_string(&self) -> String {
        self.emitted.iter().collect()
    }

    pub fn is_composing(&self) -> bool {
        !self.emitted.is_empty()
    }

    pub fn process(&mut self, key: Key) -> Output {
        self.insert.clear();
        if key != Key::Escape {
            self.undo_len = 0;
            self.undo_utf16 = 0;
            self.undo_keys = 0;
        }
        match key {
            Key::Char(c) if c.is_ascii_alphanumeric() => self.letter(c),
            Key::Char(c) => self.boundary(c),
            Key::Backspace => self.backspace(),
            Key::Escape => self.escape(),
        }
    }

    fn letter(&mut self, c: char) -> Output {
        self.raw.push(c);
        if self.raw.len() > MAX_WORD {
            self.forced = true;
        }
        if self.forced {
            self.locked = true;
            self.next.clear();
            self.next.extend_from_slice(&self.raw);
        } else {
            self.transform();
        }
        let out = self.diff();
        let natural =
            out.backspaces == 0 && self.insert.len() == 1 && self.insert[0] as u32 == c as u32;
        if natural {
            self.insert.clear();
            Output::PASS
        } else {
            Output {
                consumed: true,
                ..out
            }
        }
    }

    /// Chạy lại luật trên toàn bộ phím của từ, ghi kết quả vào `next`.
    fn transform(&mut self) {
        self.word.clear();
        self.locked = false;
        // Từ tiếng Anh đã biết thì không gõ dấu muộn ("data" không thành "dât").
        self.key_buf.clear();
        self.key_buf
            .extend(self.raw.iter().map(|c| c.to_ascii_lowercase()));
        self.word.free = !(self.english.contains(&self.key_buf)
            && !self.english_off.contains(&self.key_buf))
            && !self.exceptions.contains(&self.key_buf);
        let method = self.cfg.method;
        for &k in &self.raw {
            self.word.apply(k, method);
        }
        self.render_display();
        // Phím lặp huỷ dấu ("ass" → "as") chỉ có nghĩa khi từ vẫn là tiếng Việt tới lúc đó.
        let valid = if self.word.escaped {
            self.word.escape_ok
        } else {
            is_valid_prefix(&self.display)
        };
        self.next.clear();
        if valid {
            let p = split(&self.display);
            let tone_at = if self.word.tone != Tone::None && p.vowel_end > p.onset_end {
                let cluster = &self.display[p.onset_end..p.vowel_end];
                let has_coda = p.vowel_end < self.display.len();
                Some(p.onset_end + tone_index(cluster, has_coda, self.cfg.tone_style))
            } else {
                None
            };
            for (i, l) in self.display.iter().enumerate() {
                let tone = if Some(i) == tone_at {
                    self.word.tone
                } else {
                    Tone::None
                };
                self.next.push(l.render(tone));
            }
        } else {
            self.locked = true;
            self.next.extend_from_slice(&self.raw);
        }
    }

    /// Chữ để hiện. "uo" có móc luôn hiện "ươ" ("tươ" → "tươi", "nguơ" thì không),
    /// trừ sau h, th, kh mà chưa có gì phía sau: "huơ", "thuở", "khuơ".
    fn render_display(&mut self) {
        self.display.clear();
        self.display.extend_from_slice(&self.word.letters);
        let n = self.display.len();
        if n >= 2 {
            let p = split(&self.display);
            let e = p.vowel_end;
            let onset: Vec<u8> = self.display[..p.onset_end]
                .iter()
                .map(|l| if l.mark == Mark::None { l.base } else { 0 })
                .collect();
            let h_onset = matches!(onset.as_slice(), [b'h'] | [b't', b'h'] | [b'k', b'h']);
            if h_onset && e == n && e >= p.onset_end + 2 {
                let (u, o) = (self.display[e - 2], self.display[e - 1]);
                if u.base == b'u' && o.base == b'o' && u.mark == Mark::Horn && o.mark == Mark::Horn
                {
                    self.display[e - 2].mark = Mark::None;
                }
            }
        }
    }

    /// So `next` với chữ đang hiện, ghi chỉnh sửa vào `insert`, rồi coi `next` là chữ đang hiện.
    fn diff(&mut self) -> Output {
        let common = self
            .emitted
            .iter()
            .zip(&self.next)
            .take_while(|(a, b)| a == b)
            .count();
        let backspaces = (self.emitted.len() - common) as u32;
        let deleted_utf16 = utf16_len(&self.emitted[common..]);
        let delete_keys = clusters(&mut self.scratch, &self.emitted[common..], None);
        let mut buf = [0u16; 2];
        for c in &self.next[common..] {
            self.insert.extend_from_slice(c.encode_utf16(&mut buf));
        }
        std::mem::swap(&mut self.emitted, &mut self.next);
        Output {
            consumed: false,
            backspaces,
            deleted_utf16,
            delete_keys,
            insert_len: self.insert.len() as u32,
        }
    }

    fn boundary(&mut self, c: char) -> Output {
        if self.raw.is_empty() {
            self.clear_word();
            self.remember(&[c]);
            return Output::PASS;
        }
        self.key_buf.clear();
        self.key_buf
            .extend(self.raw.iter().map(|c| c.to_ascii_lowercase()));
        self.next.clear();
        // Trả lại phím gốc: từ người dùng đã dạy giữ nguyên, hoặc chữ biến đổi ra không phải
        // âm tiết tiếng Việt trọn vẹn mà người gõ nhiều khả năng muốn đúng phím đã gõ.
        let learned = self.exceptions.contains(&self.key_buf);
        let english = self.cfg.restore_english
            && !self.locked
            && !self.english_off.contains(&self.key_buf)
            && !is_complete(&self.display, self.word.tone)
            && self.wants_keys();
        let mut replaced = false;
        let mut expanded = false;
        if self.emitted != self.raw && (learned || english) {
            self.next.extend_from_slice(&self.raw);
            replaced = true;
        }
        let restored = replaced && english && !learned;
        if self.cfg.macros_enabled {
            let shown: String = if replaced {
                self.next.iter().collect()
            } else {
                self.emitted.iter().collect()
            };
            let expansion = self
                .macros
                .expand(&shown)
                .or_else(|| self.macros.expand(&self.key_buf));
            if let Some(exp) = expansion {
                self.undo.clear();
                self.undo.extend_from_slice(&self.emitted);
                self.undo.push(c);
                self.next.clear();
                self.next.extend(exp.chars());
                replaced = true;
                expanded = true;
            }
        }
        let out = if replaced { self.diff() } else { Output::PASS };
        // Sau diff, `emitted` là chữ đang nằm trên màn hình.
        let shown = std::mem::take(&mut self.emitted);
        if expanded {
            self.undo_len = shown.len() as u32 + 1;
            self.undo_utf16 = utf16_len(&shown) + c.len_utf16() as u32;
            self.undo_keys = clusters(&mut self.scratch, &shown, Some(c));
        }
        self.remember(&shown);
        if restored && !expanded {
            self.restored_end = Some(self.history.len());
        }
        self.remember(&[c]);
        self.emitted = shown;
        self.clear_word();
        Output {
            consumed: false,
            ..out
        }
    }

    /// Khi kết thúc từ mà chữ đang hiện không phải âm tiết trọn vẹn: người gõ muốn đúng phím đã gõ không.
    fn wants_keys(&mut self) -> bool {
        // Thêm thanh sắc hay nặng là thành chữ ("viêt" quên dấu): giữ, để xoá lùi về sửa dấu được.
        let completable = is_complete(&self.display, Tone::Acute);
        let dict = crate::text::english_dict();
        let raw_english =
            self.english.contains(&self.key_buf) || dict.contains(self.key_buf.as_str());
        if self.word.escaped {
            // Phím lặp là người gõ cố ý ("ass" → "as", "usser" → "user"). Chỉ trả phím gốc khi chữ còn sót
            // dấu tiếng Việt ("tômrow"), hoặc khi phím gốc là từ tiếng Anh còn chữ hiện ra thì không ("pass").
            if !completable && self.emitted.iter().any(|c| !c.is_ascii()) {
                return true;
            }
            self.scratch.clear();
            self.scratch
                .extend(self.emitted.iter().map(|c| c.to_ascii_lowercase()));
            let shown_english =
                self.english.contains(&self.scratch) || dict.contains(self.scratch.as_str());
            return raw_english && !shown_english;
        }
        // Một chữ cái đứng riêng ("ă", "â") hay chữ không có nguyên âm ("đc") là người gõ cố ý.
        let has_vowel = self.display.iter().any(|l| l.is_vowel());
        let lone = self.display.len() == 1 && self.word.tone == Tone::None;
        has_vowel && !lone && (!completable || raw_english)
    }

    fn backspace(&mut self) -> Output {
        if self.emitted.is_empty() {
            self.clear_word();
            // Phím xoá ăn cụm ký tự cuối của chữ đã nhớ (thường là dấu cách; cả chữ có dấu tách rời
            // hay emoji ghép trong gõ tắt, như ứng dụng xoá). Nếu ngay trước đó là một từ, lấy từ đó
            // làm từ đang gõ để sửa tiếp.
            let removed = last_cluster_len(&mut self.scratch, &self.history);
            if removed > 0 {
                self.history.truncate(self.history.len() - removed);
                let start = self
                    .history
                    .iter()
                    .rposition(|c| !c.is_alphanumeric())
                    .map_or(0, |i| i + 1);
                if start < self.history.len() {
                    let restored = self.restored_end == Some(self.history.len());
                    self.emitted.extend(self.history.drain(start..));
                    self.rebuild(restored);
                }
                // Từ đã trả phím gốc không còn trong chữ đã nhớ: quên vị trí của nó.
                if self.restored_end.is_some_and(|e| e > self.history.len()) {
                    self.restored_end = None;
                }
            }
            return Output::PASS;
        }
        self.emitted.pop();
        if self.emitted.is_empty() {
            self.clear_word();
            return Output::PASS;
        }
        if self.locked {
            self.raw.clear();
            self.raw.extend_from_slice(&self.emitted);
            return Output::PASS;
        }
        self.rebuild(false);
        Output::PASS
    }

    /// Dựng lại phím của chữ đang hiện (`emitted`) để gõ tiếp được trên nó.
    /// Không dựng lại được (chữ thô, từ tiếng Anh) thì khoá: các phím sau giữ nguyên.
    /// `restored`: đây là từ vừa được trả lại phím gốc khi kết thúc từ (xem `restored_end`).
    fn rebuild(&mut self, restored: bool) {
        let shown: String = self.emitted.iter().collect();
        let keys = crate::text::encode_keys(&shown, self.cfg.method);
        self.raw.clear();
        self.raw.extend(keys.chars());
        self.locked = false;
        let before = std::mem::take(&mut self.emitted);
        self.transform();
        if self.next != before {
            // Không dựng lại được bằng phím: giữ nguyên chữ đang hiện.
            self.locked = true;
            // Trừ khi đó là từ vừa trả lại phím gốc ("moot") mà thêm thanh là thành chữ:
            // gõ tiếp thì xét lại, để "moot ⌫ j" vẫn ra "một".
            self.forced =
                !(restored && self.raw == before && is_complete(&self.display, Tone::Acute));
            self.raw.clear();
            self.raw.extend_from_slice(&before);
        }
        self.emitted = before;
    }

    fn escape(&mut self) -> Output {
        if self.raw.is_empty() && self.undo_len > 0 {
            // Ngay sau khi gõ tắt bung ra: xoá câu và dấu cách, gõ lại đúng chữ tắt.
            let backspaces = std::mem::take(&mut self.undo_len);
            let deleted_utf16 = std::mem::take(&mut self.undo_utf16);
            let delete_keys = std::mem::take(&mut self.undo_keys);
            let mut buf = [0u16; 2];
            for c in &self.undo {
                self.insert.extend_from_slice(c.encode_utf16(&mut buf));
            }
            self.reset();
            return Output {
                consumed: true,
                backspaces,
                deleted_utf16,
                delete_keys,
                insert_len: self.insert.len() as u32,
            };
        }
        if self.raw.is_empty() || self.emitted == self.raw {
            self.reset();
            return Output::PASS;
        }
        self.next.clear();
        self.next.extend_from_slice(&self.raw);
        let out = self.diff();
        self.locked = true;
        self.forced = true;
        Output {
            consumed: true,
            ..out
        }
    }

    /// Gõ cả một chuỗi và trả về chữ hiện ra, giả lập một ô nhập chữ. Dùng cho bài thử và chuyển ngược.
    pub fn type_str(&mut self, input: &str) -> String {
        self.type_after("", input)
    }

    /// Như `type_str`, nhưng ô nhập đã có sẵn `before` và con trỏ ở cuối (đã gọi `resume`).
    pub fn type_after(&mut self, before: &str, input: &str) -> String {
        if !before.is_empty() {
            self.resume(before);
        }
        let mut screen: Vec<char> = before.chars().collect();
        for c in input.chars() {
            let key = match c {
                '\u{8}' => Key::Backspace,
                '\u{1b}' => Key::Escape,
                c => Key::Char(c),
            };
            let out = self.process(key);
            for _ in 0..out.backspaces {
                screen.pop();
            }
            screen.extend(String::from_utf16_lossy(&self.insert).chars());
            if !out.consumed {
                match key {
                    Key::Char(c) => screen.push(c),
                    Key::Backspace => {
                        screen.pop();
                    }
                    Key::Escape => {}
                }
            }
        }
        screen.into_iter().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn telex(s: &str) -> String {
        Engine::default().type_str(s)
    }

    #[test]
    fn basics() {
        assert_eq!(telex("tieesng Vieejt"), "tiếng Việt");
        assert_eq!(telex("tieengs"), "tiếng");
        assert_eq!(telex("dduowcj"), "được");
        assert_eq!(telex("nguowif"), "người");
        assert_eq!(telex("thuowr"), "thuở");
        assert_eq!(telex("hoaf"), "hoà");
        assert_eq!(telex("ass"), "as");
        assert_eq!(telex("good "), "good ");
        assert_eq!(telex("w"), "ư");
        assert_eq!(telex("ww"), "w");
    }

    #[test]
    fn backspace_keeps_state() {
        assert_eq!(telex("tieesng\u{8}\u{8}t"), "tiết");
        assert_eq!(telex("vieejt\u{8}n"), "viện");
    }

    #[test]
    fn backspace_into_previous_word() {
        // Gõ "Tiêng", cách, gõ từ khác, xoá lùi về chữ g rồi thêm dấu.
        assert_eq!(telex("Tieeng \u{8}s"), "Tiếng");
        assert_eq!(telex("Tieeng abc\u{8}\u{8}\u{8}\u{8}s"), "Tiếng");
        assert_eq!(telex("ddi hoc, \u{8}\u{8}j"), "đi học");
        assert_eq!(telex("nam vieet \u{8}j"), "nam việt");
        // Từ tiếng Anh đã trả lại phím gốc thì gõ tiếp vẫn giữ nguyên.
        assert_eq!(telex("good \u{8}s"), "goods");
        // Bấm chuột hay phím mũi tên (reset) thì quên chữ cũ.
        let mut e = Engine::default();
        e.type_str("Tieeng ");
        e.reset();
        assert_eq!(e.type_str("\u{8}s"), "s");
    }

    #[test]
    fn resume_existing_word() {
        let mut e = Engine::default();
        assert_eq!(e.type_after("Tôi ở Viêt", "j"), "Tôi ở Việt");
        assert_eq!(
            Engine::default().type_after("Xin chào hoa", "f"),
            "Xin chào hoà"
        );
        assert_eq!(Engine::default().type_after("tieng", "es"), "tiếng");
        assert_eq!(Engine::default().type_after("Việt", "f"), "Viềt");
        assert_eq!(Engine::default().type_after("hello", "s"), "hellos");
        assert_eq!(Engine::default().type_after("2024", "s"), "2024s");
        // Sau dấu cách thì là từ mới; xoá lùi vẫn nối được về từ trước.
        assert_eq!(Engine::default().type_after("hoa ", "f"), "hoa f");
        assert_eq!(Engine::default().type_after("hoa ", "\u{8}f"), "hoà");
    }

    #[test]
    fn edit_and_join_words() {
        // Đổi thanh, bỏ thanh, đổi dấu sau khi gõ xong từ.
        assert_eq!(telex("tieengsf"), "tiềng");
        assert_eq!(telex("tieengsz"), "tiêng");
        assert_eq!(telex("muaws"), "mứa");
        assert_eq!(telex("dduaw"), "đưa");
        assert_eq!(telex("cuuws"), "cứu");
        // Xoá vài chữ cuối rồi gõ lại.
        assert_eq!(telex("vieetj\u{8}n"), "viện");
        assert_eq!(telex("ngooif\u{8}ng"), "ngồng");
        // Nối lại qua dấu câu.
        assert_eq!(telex("hoa,\u{8}f"), "hoà");
        assert_eq!(telex("Vieet. \u{8}\u{8}j"), "Việt");
    }

    #[test]
    fn free_marks_inside_word() {
        assert_eq!(telex("vietje"), "việt");
        assert_eq!(telex("vietej"), "việt");
        assert_eq!(telex("tiengse"), "tiếng");
        assert_eq!(telex("duongw"), "dương");
        assert_eq!(telex("duongwf"), "dường");
        assert_eq!(telex("thuongw"), "thương");
        assert_eq!(telex("vangw"), "văng");
        assert_eq!(telex("toio"), "tôi");
        assert_eq!(telex("dieue"), "diêu");
        assert_eq!(telex("nguoiwf"), "người");
        // Từ tiếng Anh vẫn giữ nguyên.
        assert_eq!(telex("data "), "data ");
        assert_eq!(telex("video "), "video ");
        assert_eq!(telex("hello "), "hello ");
        assert_eq!(telex("answer "), "answer ");
        assert_eq!(telex("ngoeo"), "ngoeo");
    }

    #[test]
    fn escape_undoes_macro() {
        let mut e = Engine::default();
        e.set_macros(MacroTable::from_tsv("ksao\tKhông sao đâu"));
        assert_eq!(e.type_str("ksao "), "Không sao đâu ");
        let mut e2 = Engine::default();
        e2.set_macros(MacroTable::from_tsv("ksao\tKhông sao đâu"));
        assert_eq!(e2.type_str("ksao \u{1b}"), "ksao ");
        assert_eq!(e2.type_str("ksao x\u{1b}"), "Không sao đâu x");
    }

    #[test]
    fn reset_forgets_macro_undo() {
        // Bung gõ tắt rồi bấm chuột sang chỗ khác: esc không được xoá chữ ở chỗ mới.
        let mut e = Engine::default();
        e.set_macros(MacroTable::from_tsv("ksao\tKhông sao đâu"));
        assert_eq!(e.type_str("ksao "), "Không sao đâu ");
        e.reset();
        let out = e.process(Key::Escape);
        assert_eq!(out.backspaces, 0);
        assert!(!out.consumed);
    }

    #[test]
    fn escape_counts_utf16_for_emoji_macro() {
        // "😀 " là 2 ký tự nhưng 3 đơn vị UTF-16: nơi xoá theo NSRange phải xoá đủ 3.
        let mut e = Engine::default();
        e.set_macros(MacroTable::from_tsv("cuoi\t😀"));
        assert_eq!(e.type_str("cuoi "), "😀 ");
        let out = e.process(Key::Escape);
        assert!(out.consumed);
        assert_eq!(out.backspaces, 2);
        assert_eq!(out.deleted_utf16, 3);
        assert_eq!(out.delete_keys, 2);
        assert_eq!(e.insert_string(), "cuoi ");
    }

    #[test]
    fn backspace_removes_whole_cluster_from_history() {
        // Gõ tắt bung ra "hoa" + dấu huyền kết hợp (dấu tách rời). Ứng dụng xoá "à" trong một lần bấm,
        // nên lõi cũng phải bỏ cả "a" lẫn dấu: còn "ho", gõ f ra "hò" chứ không phải "hà".
        let mut e = Engine::default();
        e.set_macros(MacroTable::from_tsv("hh\thoa\u{300}"));
        for c in "hh ".chars() {
            e.process(Key::Char(c));
        }
        e.process(Key::Backspace);
        e.process(Key::Backspace);
        let out = e.process(Key::Char('f'));
        assert_eq!(e.current_word_string(), "hò");
        assert_eq!(out.backspaces, 1);
        assert_eq!(e.insert_string(), "ò");
        // Emoji ghép: một lần xoá là hết, chữ trước nó vẫn còn nguyên để sửa tiếp.
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}";
        let mut e = Engine::default();
        e.set_macros(MacroTable::from_tsv(&format!("gd\tnha{family}")));
        for c in "gd ".chars() {
            e.process(Key::Char(c));
        }
        e.process(Key::Backspace);
        e.process(Key::Backspace);
        e.process(Key::Char('f'));
        assert_eq!(e.current_word_string(), "nhà");
    }

    #[test]
    fn escape_counts_key_presses_for_joined_emoji() {
        // 👨‍👩‍👧‍👦 là 7 ký tự (4 người nối bằng ZWJ) nhưng một phím xoá là hết: gõ đè chỉ bấm 2 lần (emoji, dấu cách).
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}";
        let mut e = Engine::default();
        e.set_macros(MacroTable::from_tsv(&format!("gd\t{family}")));
        assert_eq!(e.type_str("gd "), format!("{family} "));
        let out = e.process(Key::Escape);
        assert_eq!(out.backspaces, 8);
        assert_eq!(out.deleted_utf16, 12);
        assert_eq!(out.delete_keys, 2);
        // Chữ tiếng Việt: mỗi ký tự một lần xoá ("tiêng" thêm s: xoá "êng", gõ "ếng").
        let mut v = Engine::default();
        for c in "tieeng".chars() {
            v.process(Key::Char(c));
        }
        let out = v.process(Key::Char('s'));
        assert_eq!(out.backspaces, 3);
        assert_eq!(out.delete_keys, 3);
    }

    #[test]
    fn english_lists() {
        let mut e = Engine::default();
        assert_eq!(e.type_str("user "), "user ");
        e.set_english_off(["user".to_string()]);
        assert_ne!(Engine::default().type_str("user "), e.type_str("user "));
        let mut e = Engine::default();
        e.set_exceptions(["test".to_string()]);
        assert_eq!(e.type_str("test "), "test ");
    }

    #[test]
    fn repeat_key_keeps_english_letters() {
        // Từ đã không phải tiếng Việt thì phím lặp không làm mất chữ ("proges", "clas").
        assert_eq!(telex("progress"), "progress");
        assert_eq!(telex("class"), "class");
        assert_eq!(telex("careers"), "careers");
        // Từ còn là tiếng Việt thì phím lặp vẫn huỷ dấu như Telex.
        assert_eq!(telex("ass"), "as");
        assert_eq!(telex("thiss"), "this");
    }

    #[test]
    fn restore_keys_at_word_end() {
        // Không thành âm tiết tiếng Việt dù thêm thanh: trả phím gốc.
        assert_eq!(telex("sure "), "sure ");
        assert_eq!(telex("tomorrow "), "tomorrow ");
        // Phím gốc là từ tiếng Anh, chữ huỷ dấu ra thì không.
        assert_eq!(telex("pass "), "pass ");
        assert_eq!(telex("usser "), "user ");
        // Từ tiếng Anh mà chữ ra chỉ thiếu thanh: trả phím gốc, xoá lùi về vẫn thêm thanh được.
        assert_eq!(telex("keep "), "keep ");
        assert_eq!(telex("moot \u{8}j"), "một");
        assert_eq!(telex("moot abc \u{8}\u{8}\u{8}\u{8}\u{8}j"), "một");
        // Chữ có sẵn trước con trỏ thì không: "keep" thêm s vẫn là "keeps".
        assert_eq!(Engine::default().type_after("keep", "s "), "keeps ");
        assert_eq!(Engine::default().type_after("moot ", "\u{8}j"), "mootj");
        // Tiếng Việt quên thanh thì giữ, để sửa sau.
        assert_eq!(telex("vieet "), "viêt ");
        assert_eq!(telex("aw "), "ă ");
        // Từ người dùng tắt trong danh sách thì không trả.
        let mut e = Engine::default();
        e.set_english_off(["sure".to_string()]);
        assert_ne!(e.type_str("sure "), "sure ");
    }

    #[test]
    fn uo_with_horn() {
        assert_eq!(telex("uow"), "ươ");
        assert_eq!(telex("tuow"), "tươ");
        assert_eq!(telex("nguowi"), "ngươi");
        assert_eq!(telex("dduow"), "đươ");
        assert_eq!(telex("uwow"), "ươ");
        assert_eq!(telex("huow"), "huơ");
        assert_eq!(telex("thuowr"), "thuở");
        assert_eq!(telex("huowu"), "hươu");
        assert_eq!(telex("quow"), "quơ");
    }

    #[test]
    fn escape_restores_keys() {
        assert_eq!(telex("tieesng\u{1b}"), "tieesng");
    }
}
