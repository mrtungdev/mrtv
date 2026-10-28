//! Luật phím của Telex, Telex đơn giản và VNI.
//!
//! Mỗi phím được áp lên `Word` (các chữ cái + thanh của từ đang gõ).
//! Bộ máy gõ chạy lại toàn bộ phím của từ sau mỗi lần bấm, nên các luật ở đây
//! chỉ cần đúng theo thứ tự phím, không phải lo trạng thái màn hình.

use crate::engine::Method;
use crate::letters::{Letter, Mark, Tone};
use crate::syllable::{is_valid_prefix, split};

#[derive(Clone, Debug, Default)]
pub(crate) struct Word {
    pub letters: Vec<Letter>,
    pub tone: Tone,
    /// Đã bấm phím lặp để huỷ dấu ("ass" → "as"): các phím sau giữ nguyên.
    pub escaped: bool,
    /// Cho gõ dấu mũ, dấu móc ở bất kỳ đâu trong từ ("vietje" → "việt"). Tắt cho từ tiếng Anh đã biết.
    pub free: bool,
    /// Ngay trước phím lặp, chữ vẫn còn là tiếng Việt. Không thì phím lặp chỉ là chữ thường và
    /// từ giữ phím thô: "progress" không thành "proges".
    pub escape_ok: bool,
    last: Last,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
enum Last {
    #[default]
    None,
    StandaloneHorn,
}

impl Word {
    pub fn with_capacity(n: usize) -> Word {
        Word {
            letters: Vec::with_capacity(n),
            free: true,
            ..Word::default()
        }
    }

    pub fn clear(&mut self) {
        self.letters.clear();
        self.tone = Tone::None;
        self.escaped = false;
        self.escape_ok = false;
        self.last = Last::None;
    }

    fn push(&mut self, key: char) {
        self.letters.push(Letter::from_key(key));
        self.last = Last::None;
    }

    /// Huỷ thao tác vừa làm và giữ phím như chữ thường.
    fn escape_with(&mut self, key: char) {
        self.escape_ok = is_valid_prefix(&self.letters);
        self.push(key);
        self.escaped = true;
    }

    fn vowels(&self) -> (usize, usize, bool) {
        let p = split(&self.letters);
        (p.onset_end, p.vowel_end, p.vowel_end < self.letters.len())
    }

    fn find_uo(&self, s: usize, e: usize) -> Option<usize> {
        (s..e.saturating_sub(1))
            .find(|&i| self.letters[i].base == b'u' && self.letters[i + 1].base == b'o')
    }

    fn set_tone(&mut self, tone: Tone, key: char) {
        if self.tone == tone {
            self.tone = Tone::None;
            self.escape_with(key);
        } else {
            self.tone = tone;
            self.last = Last::None;
        }
    }

    fn circumflex(&mut self, i: usize, key: char) {
        match self.letters[i].mark {
            Mark::Circumflex => {
                self.letters[i].mark = Mark::None;
                self.escape_with(key);
            }
            Mark::None | Mark::Breve | Mark::Horn => {
                self.letters[i].mark = Mark::Circumflex;
                self.last = Last::None;
            }
            Mark::Stroke => self.push(key),
        }
    }

    fn toggle(&mut self, i: usize, mark: Mark, key: char) {
        if self.letters[i].mark == mark {
            self.letters[i].mark = Mark::None;
            self.escape_with(key);
        } else {
            self.letters[i].mark = mark;
            self.last = Last::None;
        }
    }

    /// Đặt dấu mũ hoặc móc lên chữ ở vị trí `i` nếu từ vẫn là tiếng Việt hợp lệ; không thì thôi.
    /// Dùng cho dấu gõ muộn: sau âm cuối ("vietje"), hoặc không ngay sau nguyên âm cần dấu ("toio").
    fn try_mark(&mut self, positions: &[usize], mark: Mark) -> bool {
        let saved: Vec<Mark> = positions.iter().map(|&i| self.letters[i].mark).collect();
        for &i in positions {
            self.letters[i].mark = mark;
        }
        if is_valid_prefix(&self.letters) {
            self.last = Last::None;
            return true;
        }
        for (&i, m) in positions.iter().zip(saved) {
            self.letters[i].mark = m;
        }
        false
    }

    /// ă / ơ / ư / ươ gõ muộn bằng w.
    fn late_hook(&mut self, s: usize, e: usize) -> bool {
        if let Some(i) = self.find_uo(s, e) {
            if self.letters[i].mark != Mark::Horn || self.letters[i + 1].mark != Mark::Horn {
                return self.try_mark(&[i, i + 1], Mark::Horn);
            }
        }
        for (base, mark) in [(b'a', Mark::Breve), (b'o', Mark::Horn), (b'u', Mark::Horn)] {
            if let Some(i) = (s..e)
                .rev()
                .find(|&i| self.letters[i].base == base && self.letters[i].mark == Mark::None)
            {
                if self.try_mark(&[i], mark) {
                    return true;
                }
            }
        }
        false
    }

    fn horn_pair(&mut self, i: usize, key: char) {
        if self.letters[i].mark == Mark::Horn && self.letters[i + 1].mark == Mark::Horn {
            self.letters[i].mark = Mark::None;
            self.letters[i + 1].mark = Mark::None;
            self.escape_with(key);
        } else {
            self.letters[i].mark = Mark::Horn;
            self.letters[i + 1].mark = Mark::Horn;
            self.last = Last::None;
        }
    }

    /// ă / ơ / ư / ươ, dùng chung cho Telex (w) và VNI (7, 8).
    /// Thử lần lượt: cặp uo → ươ, a → ă, o → ơ, u → ư (mỗi chữ từ phải sang trái), lấy chỗ đầu tiên
    /// cho ra tiếng Việt hợp lệ: "uaw" → "ưa" (không phải "uă"), "uuw" → "ưu". Chữ đã có đúng dấu đó
    /// thì bấm lần nữa là bỏ dấu ("aww" → "aw").
    fn hook_or_breve(
        &mut self,
        s: usize,
        e: usize,
        key: char,
        allow_breve: bool,
        allow_horn: bool,
    ) -> bool {
        if allow_horn {
            if let Some(i) = self.find_uo(s, e) {
                let both =
                    self.letters[i].mark == Mark::Horn && self.letters[i + 1].mark == Mark::Horn;
                if both || self.try_mark(&[i, i + 1], Mark::Horn) {
                    if both {
                        self.horn_pair(i, key);
                    }
                    return true;
                }
            }
        }
        let mut candidates: Vec<(usize, Mark)> = Vec::new();
        if allow_breve {
            candidates.extend(
                (s..e)
                    .rev()
                    .filter(|&i| self.letters[i].base == b'a')
                    .map(|i| (i, Mark::Breve)),
            );
        }
        if allow_horn {
            for base in *b"ou" {
                candidates.extend(
                    (s..e)
                        .rev()
                        .filter(|&i| self.letters[i].base == base)
                        .map(|i| (i, Mark::Horn)),
                );
            }
        }
        // Bấm lặp: chữ đã mang đúng dấu này thì bỏ dấu và giữ phím.
        if let Some(&(i, mark)) = candidates.iter().find(|&&(i, m)| self.letters[i].mark == m) {
            self.toggle(i, mark, key);
            return true;
        }
        for &(i, mark) in &candidates {
            if self.try_mark(&[i], mark) {
                return true;
            }
        }
        // Không chỗ nào hợp lệ: đặt như cũ để chữ hiện ra đúng phím người dùng gõ.
        if let Some(&(i, mark)) = candidates.first() {
            self.toggle(i, mark, key);
            return true;
        }
        false
    }

    fn stroke(&mut self, key: char) -> bool {
        match self.letters.first().map(|l| (l.base, l.mark)) {
            Some((b'd', Mark::None)) => {
                self.letters[0].mark = Mark::Stroke;
                self.last = Last::None;
                true
            }
            Some((b'd', Mark::Stroke)) => {
                self.letters[0].mark = Mark::None;
                self.escape_with(key);
                true
            }
            _ => false,
        }
    }

    pub fn apply(&mut self, key: char, method: Method) {
        if self.escaped || !key.is_ascii_alphanumeric() {
            self.push(key);
            return;
        }
        match method {
            Method::Telex | Method::SimpleTelex => self.apply_telex(key, method == Method::Telex),
            Method::Vni => self.apply_vni(key),
        }
    }

    fn apply_telex(&mut self, key: char, w_standalone: bool) {
        let k = key.to_ascii_lowercase();
        let (s, e, has_coda) = self.vowels();
        let has_vowel = e > s;
        match k {
            's' | 'f' | 'r' | 'x' | 'j' if has_vowel => {
                let tone = match k {
                    's' => Tone::Acute,
                    'f' => Tone::Grave,
                    'r' => Tone::Hook,
                    'x' => Tone::Tilde,
                    _ => Tone::Dot,
                };
                self.set_tone(tone, key);
            }
            'z' if has_vowel && self.tone != Tone::None => {
                self.tone = Tone::None;
                self.last = Last::None;
            }
            // Gấp đôi nguyên âm cuối của vần: aa → â, ee → ê, oo → ô ("ngoeo" vẫn giữ 3 nguyên âm).
            'a' | 'e' | 'o' if has_vowel && !has_coda && self.letters[e - 1].base == k as u8 => {
                self.circumflex(e - 1, key)
            }
            // Gõ dấu mũ muộn: "vietje" → "việt", "tiengse" → "tiếng", "toio" → "tôi".
            'a' | 'e' | 'o' if self.free && has_vowel => {
                let target = (s..e).rev().find(|&i| {
                    self.letters[i].base == k as u8 && self.letters[i].mark == Mark::None
                });
                if !target.is_some_and(|i| self.try_mark(&[i], Mark::Circumflex)) {
                    self.push(key);
                }
            }
            'w' => {
                if self.last == Last::StandaloneHorn {
                    if let Some(l) = self.letters.last() {
                        if l.base == b'u' && l.mark == Mark::Horn {
                            self.letters.pop();
                            self.escape_with(key);
                            return;
                        }
                    }
                }
                if has_vowel && !has_coda && self.hook_or_breve(s, e, key, true, true) {
                    return;
                }
                // Gõ dấu móc muộn: "duongw" → "dương", "vangw" → "văng".
                if self.free && has_vowel && has_coda && self.late_hook(s, e) {
                    return;
                }
                if w_standalone && !has_coda {
                    self.letters
                        .push(Letter::new(b'u', Mark::Horn, key.is_ascii_uppercase()));
                    self.last = Last::StandaloneHorn;
                } else {
                    self.push(key);
                }
            }
            'd' if self.letters.len() == 1 => {
                if !self.stroke(key) {
                    self.push(key);
                }
            }
            _ => self.push(key),
        }
    }

    fn apply_vni(&mut self, key: char) {
        let (s, e, _) = self.vowels();
        let has_vowel = e > s;
        let handled = match key {
            '1'..='5' if has_vowel => {
                let tone = Tone::from_index(key as usize - '0' as usize);
                self.set_tone(tone, key);
                true
            }
            '0' if has_vowel && self.tone != Tone::None => {
                self.tone = Tone::None;
                true
            }
            '6' if has_vowel => {
                let target = (s..e)
                    .rev()
                    .find(|&i| matches!(self.letters[i].base, b'a' | b'e' | b'o'));
                match target {
                    Some(i) => {
                        self.circumflex(i, key);
                        true
                    }
                    None => false,
                }
            }
            '7' if has_vowel => self.hook_or_breve(s, e, key, false, true),
            '8' if has_vowel => self.hook_or_breve(s, e, key, true, false),
            '9' => self.stroke(key),
            _ => false,
        };
        if !handled {
            self.push(key);
        }
    }
}
