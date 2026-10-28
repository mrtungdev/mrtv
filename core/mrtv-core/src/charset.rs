//! Đổi bảng mã cũ sang Unicode: VIQR và TCVN3 (ABC).
//!
//! VNI-Windows chưa có: cần một bảng đối chiếu đáng tin trước khi làm (xem docs/tech-stack.md).

use crate::letters::{decompose, Letter, Mark, Tone};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Charset {
    Viqr,
    Tcvn3,
}

/// Chữ TCVN3 (ABC) thường bị hiện như chữ Latin-1 lạ khi dán: "ViÖt Nam", "Hµ Néi".
/// Mỗi cặp là (mã byte TCVN3, chữ Unicode). [CẦN ĐỐI CHIẾU] với bảng chuẩn TCVN 5712:1993.
const TCVN3: &[(u8, char)] = &[
    (0xA1, 'Ă'),
    (0xA2, 'Â'),
    (0xA3, 'Ê'),
    (0xA4, 'Ô'),
    (0xA5, 'Ơ'),
    (0xA6, 'Ư'),
    (0xA7, 'Đ'),
    (0xA8, 'ă'),
    (0xA9, 'â'),
    (0xAA, 'ê'),
    (0xAB, 'ô'),
    (0xAC, 'ơ'),
    (0xAD, 'ư'),
    (0xAE, 'đ'),
    (0xB5, 'à'),
    (0xB6, 'ả'),
    (0xB7, 'ã'),
    (0xB8, 'á'),
    (0xB9, 'ạ'),
    (0xBB, 'ằ'),
    (0xBC, 'ẳ'),
    (0xBD, 'ẵ'),
    (0xBE, 'ắ'),
    (0xC6, 'ặ'),
    (0xC7, 'ầ'),
    (0xC8, 'ẩ'),
    (0xC9, 'ẫ'),
    (0xCA, 'ấ'),
    (0xCB, 'ậ'),
    (0xCC, 'è'),
    (0xCE, 'ẻ'),
    (0xCF, 'ẽ'),
    (0xD0, 'é'),
    (0xD1, 'ẹ'),
    (0xD2, 'ề'),
    (0xD3, 'ể'),
    (0xD4, 'ễ'),
    (0xD5, 'ế'),
    (0xD6, 'ệ'),
    (0xD7, 'ì'),
    (0xD8, 'ỉ'),
    (0xDC, 'ĩ'),
    (0xDD, 'í'),
    (0xDE, 'ị'),
    (0xDF, 'ò'),
    (0xE1, 'ỏ'),
    (0xE2, 'õ'),
    (0xE3, 'ó'),
    (0xE4, 'ọ'),
    (0xE5, 'ồ'),
    (0xE6, 'ổ'),
    (0xE7, 'ỗ'),
    (0xE8, 'ố'),
    (0xE9, 'ộ'),
    (0xEA, 'ờ'),
    (0xEB, 'ở'),
    (0xEC, 'ỡ'),
    (0xED, 'ớ'),
    (0xEE, 'ợ'),
    (0xEF, 'ù'),
    (0xF1, 'ủ'),
    (0xF2, 'ũ'),
    (0xF3, 'ú'),
    (0xF4, 'ụ'),
    (0xF5, 'ừ'),
    (0xF6, 'ử'),
    (0xF7, 'ữ'),
    (0xF8, 'ứ'),
    (0xF9, 'ự'),
    (0xFA, 'ỳ'),
    (0xFB, 'ỷ'),
    (0xFC, 'ỹ'),
    (0xFD, 'ý'),
    (0xFE, 'ỵ'),
];

pub fn to_unicode(input: &str, from: Charset) -> String {
    match from {
        Charset::Viqr => viqr_to_unicode(input),
        Charset::Tcvn3 => input
            .chars()
            .map(|c| {
                let code = c as u32;
                if (0xA1..=0xFE).contains(&code) {
                    TCVN3
                        .iter()
                        .find(|(b, _)| *b as u32 == code)
                        .map(|(_, u)| *u)
                        .unwrap_or(c)
                } else {
                    c
                }
            })
            .collect(),
    }
}

/// Đoán chữ có phải TCVN3 dán nhầm không, để thanh gợi ý đề xuất "Đổi bảng mã".
pub fn looks_like_tcvn3(input: &str) -> bool {
    let hits = input
        .chars()
        .filter(|&c| TCVN3.iter().any(|(b, _)| *b as u32 == c as u32))
        .count();
    hits >= 2
        && !input
            .chars()
            .any(|c| ('\u{1EA0}'..='\u{1EF9}').contains(&c))
}

fn viqr_tone(c: char) -> Option<Tone> {
    match c {
        '\'' => Some(Tone::Acute),
        '`' => Some(Tone::Grave),
        '?' => Some(Tone::Hook),
        '~' => Some(Tone::Tilde),
        '.' => Some(Tone::Dot),
        _ => None,
    }
}

fn viqr_mark(base: u8, c: char) -> Option<Mark> {
    match (base, c) {
        (b'a', '(') => Some(Mark::Breve),
        (b'a' | b'e' | b'o', '^') => Some(Mark::Circumflex),
        (b'o' | b'u', '+') => Some(Mark::Horn),
        _ => None,
    }
}

/// VIQR: a( → ă, a^ → â, o+ → ơ, dd → đ, dấu ' ` ? ~ . đặt ngay sau nguyên âm. "\" giữ nguyên ký tự sau.
pub fn viqr_to_unicode(input: &str) -> String {
    let cs: Vec<char> = input.chars().collect();
    let mut out = String::with_capacity(input.len());
    let mut i = 0;
    while i < cs.len() {
        let c = cs[i];
        if c == '\\' && i + 1 < cs.len() {
            out.push(cs[i + 1]);
            i += 2;
            continue;
        }
        if (c == 'd' || c == 'D') && i + 1 < cs.len() && cs[i + 1].eq_ignore_ascii_case(&'d') {
            out.push(if c == 'D' { 'Đ' } else { 'đ' });
            i += 2;
            continue;
        }
        let lower = c.to_ascii_lowercase() as u8;
        if c.is_ascii_alphabetic() && crate::letters::is_vowel_base(lower) {
            let mut l = Letter::new(lower, Mark::None, c.is_ascii_uppercase());
            let mut j = i + 1;
            if j < cs.len() {
                if let Some(m) = viqr_mark(lower, cs[j]) {
                    l.mark = m;
                    j += 1;
                }
            }
            let mut tone = Tone::None;
            // Theo RFC 1456: dấu ngay sau nguyên âm luôn là thanh; muốn giữ dấu câu thì viết "\?".
            if let Some(t) = cs.get(j).and_then(|&n| viqr_tone(n)) {
                tone = t;
                j += 1;
            }
            out.push(l.render(tone));
            i = j;
            continue;
        }
        out.push(c);
        i += 1;
    }
    out
}

/// Unicode → VIQR, để kiểm tra chiều ngược lại.
pub fn unicode_to_viqr(input: &str) -> String {
    let mut out = String::with_capacity(input.len() * 2);
    let mut after_vowel = false;
    for c in input.chars() {
        let vowel = decompose(c)
            .is_some_and(|(b, m, _, _)| m != Mark::Stroke && crate::letters::is_vowel_base(b));
        // Dấu câu ngay sau nguyên âm phải thoát bằng "\" để không bị đọc thành thanh.
        if after_vowel && matches!(c, '\'' | '`' | '?' | '~' | '.' | '(' | '^' | '+') {
            out.push('\\');
        }
        after_vowel = vowel;
        match decompose(c) {
            Some((b'd', Mark::Stroke, _, up)) => out.push_str(if up { "DD" } else { "dd" }),
            Some((b, m, t, up)) if !c.is_ascii() => {
                let base = if up {
                    (b as char).to_ascii_uppercase()
                } else {
                    b as char
                };
                out.push(base);
                match m {
                    Mark::Breve => out.push('('),
                    Mark::Circumflex => out.push('^'),
                    Mark::Horn => out.push('+'),
                    _ => {}
                }
                match t {
                    Tone::Acute => out.push('\''),
                    Tone::Grave => out.push('`'),
                    Tone::Hook => out.push('?'),
                    Tone::Tilde => out.push('~'),
                    Tone::Dot => out.push('.'),
                    Tone::None => {}
                }
            }
            _ => out.push(c),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tcvn3_known_samples() {
        assert_eq!(to_unicode("ViÖt Nam", Charset::Tcvn3), "Việt Nam");
        assert_eq!(to_unicode("Hµ Néi", Charset::Tcvn3), "Hà Nội");
        assert_eq!(to_unicode("TiÕng ViÖt", Charset::Tcvn3), "Tiếng Việt");
        assert!(looks_like_tcvn3("TiÕng ViÖt"));
        assert!(!looks_like_tcvn3("Tiếng Việt"));
    }

    #[test]
    fn viqr_both_ways() {
        assert_eq!(viqr_to_unicode("Tie^'ng Vie^.t"), "Tiếng Việt");
        assert_eq!(viqr_to_unicode("DDa(ng ky' kho^ng?"), "Đăng ký không?");
        assert_eq!(
            viqr_to_unicode(&unicode_to_viqr("Người Việt ở đâu?")),
            "Người Việt ở đâu?"
        );
    }
}
