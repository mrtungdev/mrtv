//! Công cụ chữ cho thanh gợi ý và bảng lệnh: các việc chạy bằng quy tắc, không cần AI.

use std::collections::HashSet;
use std::sync::OnceLock;

use unicode_normalization::char::is_combining_mark;
use unicode_normalization::UnicodeNormalization;

use crate::engine::{Config, Engine, Method};
use crate::letters::{decompose, Mark, Tone};

/// Chuẩn hoá về Unicode dựng sẵn (NFC). Sửa chữ bị tách dấu khi chép từ macOS sang Windows, web.
pub fn nfc(s: &str) -> String {
    s.nfc().collect()
}

pub fn is_nfc(s: &str) -> bool {
    unicode_normalization::is_nfc(s)
}

/// Bỏ dấu: "Tiếng Việt" → "Tieng Viet".
pub fn strip_diacritics(s: &str) -> String {
    s.nfd()
        .filter(|c| !('\u{300}'..='\u{36F}').contains(c))
        .map(|c| match c {
            'đ' => 'd',
            'Đ' => 'D',
            c => c,
        })
        .collect()
}

/// Đường dẫn không dấu: "Báo cáo Quý 3!" → "bao-cao-quy-3".
pub fn slug(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut dash = false;
    for c in strip_diacritics(s).chars() {
        if c.is_ascii_alphanumeric() {
            if dash && !out.is_empty() {
                out.push('-');
            }
            dash = false;
            out.push(c.to_ascii_lowercase());
        } else {
            dash = true;
        }
    }
    out
}

pub fn upper(s: &str) -> String {
    s.to_uppercase()
}

pub fn lower(s: &str) -> String {
    s.to_lowercase()
}

/// Viết Hoa Đầu Mỗi Từ. Dấu kết hợp (chữ dấu tách rời: "e" + dấu mũ + dấu nặng) thuộc về chữ đứng trước,
/// không phải chỗ ngắt từ: "Vie\u{302}\u{323}t" vẫn là một từ.
pub fn title(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut start = true;
    for c in s.chars() {
        if c.is_alphabetic() {
            if start {
                out.extend(c.to_uppercase());
            } else {
                out.extend(c.to_lowercase());
            }
            start = false;
        } else if is_combining_mark(c) {
            out.push(c);
        } else {
            out.push(c);
            start = true;
        }
    }
    out
}

/// Viết hoa đầu câu.
pub fn sentence(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut start = true;
    for c in s.chars() {
        if c.is_alphabetic() {
            if start {
                out.extend(c.to_uppercase());
            } else {
                out.extend(c.to_lowercase());
            }
            start = false;
        } else {
            if matches!(c, '.' | '!' | '?' | '\n') {
                start = true;
            }
            out.push(c);
        }
    }
    out
}

/// Đổi chữ tiếng Việt thành chuỗi phím cần gõ: "được" → "dduowcj" (Telex), "dduo7c5" (VNI).
/// Thanh đặt ở cuối từ, nên chạy lại bộ máy gõ sẽ ra đúng chữ ban đầu.
pub fn encode_keys(word: &str, method: Method) -> String {
    let mut out = String::with_capacity(word.len() * 2);
    let mut tone = Tone::None;
    let mut tone_upper = false;
    for c in word.chars() {
        let Some((b, m, t, up)) = decompose(c) else {
            out.push(c);
            continue;
        };
        if t != Tone::None {
            tone = t;
            tone_upper = up;
        }
        let base = if up {
            (b as char).to_ascii_uppercase()
        } else {
            b as char
        };
        out.push(base);
        let modifier = match (method, m, b) {
            (_, Mark::None, _) => None,
            (Method::Vni, Mark::Circumflex, _) => Some('6'),
            (Method::Vni, Mark::Horn, _) => Some('7'),
            (Method::Vni, Mark::Breve, _) => Some('8'),
            (Method::Vni, Mark::Stroke, _) => Some('9'),
            (_, Mark::Circumflex, b) => Some(b as char),
            (_, Mark::Breve, _) | (_, Mark::Horn, _) => Some('w'),
            (_, Mark::Stroke, _) => Some('d'),
        };
        if let Some(k) = modifier {
            out.push(if up && k.is_ascii_alphabetic() {
                k.to_ascii_uppercase()
            } else {
                k
            });
        }
    }
    let key = match (method, tone) {
        (_, Tone::None) => None,
        (Method::Vni, t) => char::from_digit(t.index() as u32, 10),
        (_, Tone::Acute) => Some('s'),
        (_, Tone::Grave) => Some('f'),
        (_, Tone::Hook) => Some('r'),
        (_, Tone::Tilde) => Some('x'),
        (_, Tone::Dot) => Some('j'),
    };
    if let Some(k) = key {
        out.push(if tone_upper && word.chars().all(|c| !c.is_lowercase()) {
            k.to_ascii_uppercase()
        } else {
            k
        });
    }
    out
}

/// Chuyển ngược: chữ lỡ gõ khi đang ở chế độ Anh ("tooi ddang") thành tiếng Việt ("tôi đang").
/// Chỉ đổi những từ ra được âm tiết tiếng Việt trọn vẹn; từ khác giữ nguyên.
pub fn reverse(s: &str, method: Method) -> String {
    let mut engine = Engine::new(Config {
        method,
        restore_english: false,
        macros_enabled: false,
        ..Config::default()
    });
    let mut out = String::with_capacity(s.len());
    let mut word = String::new();
    let flush = |word: &mut String, out: &mut String, engine: &mut Engine| {
        if word.is_empty() {
            return;
        }
        engine.reset();
        let typed = engine.type_str(word);
        let ok =
            typed != *word && crate::syllable::is_complete(&letters_of(&typed), tone_of(&typed));
        out.push_str(if ok { &typed } else { word });
        word.clear();
    };
    for c in s.chars() {
        if c.is_ascii_alphanumeric() {
            word.push(c);
        } else {
            flush(&mut word, &mut out, &mut engine);
            out.push(c);
        }
    }
    flush(&mut word, &mut out, &mut engine);
    out
}

fn letters_of(s: &str) -> Vec<crate::letters::Letter> {
    s.chars()
        .filter_map(decompose)
        .map(|(b, m, _, up)| crate::letters::Letter::new(b, m, up))
        .collect()
}

fn tone_of(s: &str) -> Tone {
    s.chars()
        .filter_map(decompose)
        .map(|(_, _, t, _)| t)
        .find(|t| *t != Tone::None)
        .unwrap_or(Tone::None)
}

/// Từ tiếng Anh hay gặp, dùng để trả lại phím gốc khi kết thúc từ.
/// Danh sách từ tiếng Anh có sẵn, xếp theo bảng chữ cái (để hiện trong Cài đặt).
pub fn english_list() -> Vec<String> {
    let mut list: Vec<String> = english_words().into_iter().collect();
    list.sort();
    list
}

pub fn english_words() -> HashSet<String> {
    include_str!("../data/english.txt")
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(str::to_lowercase)
        .collect()
}

/// Từ điển tiếng Anh ẩn (~39 nghìn từ thông dụng, từ SCOWL; tạo bằng scripts/gen-english-dict.sh).
/// Chỉ dùng khi kết thúc từ, để biết người gõ "pass", "error" hay "keep" muốn đúng phím đã gõ.
/// Nạp một lần cho mọi bộ máy gõ.
pub fn english_dict() -> &'static HashSet<&'static str> {
    static DICT: OnceLock<HashSet<&'static str>> = OnceLock::new();
    DICT.get_or_init(|| {
        include_str!("../data/english-dict.txt")
            .lines()
            .filter(|l| !l.is_empty() && !l.starts_with('#'))
            .collect()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tools() {
        assert_eq!(strip_diacritics("Tiếng Việt, đường"), "Tieng Viet, duong");
        assert_eq!(slug("Báo cáo Quý 3 — Đà Nẵng!"), "bao-cao-quy-3-da-nang");
        assert_eq!(title("xin chào việt nam"), "Xin Chào Việt Nam");
        // Chữ dấu tách rời: dấu kết hợp không cắt từ.
        assert_eq!(title("Vie\u{302}\u{323}t Nam"), "Vie\u{302}\u{323}t Nam");
        assert_eq!(title("vie\u{302}\u{323}t nam"), "Vie\u{302}\u{323}t Nam");
        assert_eq!(sentence("hôm nay. ngày mai"), "Hôm nay. Ngày mai");
        let decomposed = "Vie\u{302}\u{323}t";
        assert!(!is_nfc(decomposed));
        assert_eq!(nfc(decomposed), "Việt");
    }

    #[test]
    fn encode() {
        assert_eq!(encode_keys("được", Method::Telex), "dduwowcj");
        assert_eq!(encode_keys("Việt", Method::Telex), "Vieetj");
        assert_eq!(encode_keys("được", Method::Vni), "d9u7o7c5");
    }

    #[test]
    fn reverse_typing() {
        assert_eq!(
            reverse("tooi ddang gox tieesng Vieejt, ok?", Method::Telex),
            "tôi đang gõ tiếng Việt, ok?"
        );
    }
}
