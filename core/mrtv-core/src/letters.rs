//! Chữ cái tiếng Việt: chữ gốc, dấu phụ (mũ, trăng, móc, gạch ngang) và thanh điệu.

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum Mark {
    #[default]
    None,
    /// â ê ô
    Circumflex,
    /// ă
    Breve,
    /// ơ ư
    Horn,
    /// đ
    Stroke,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum Tone {
    #[default]
    None,
    /// sắc
    Acute,
    /// huyền
    Grave,
    /// hỏi
    Hook,
    /// ngã
    Tilde,
    /// nặng
    Dot,
}

impl Tone {
    pub const fn index(self) -> usize {
        match self {
            Tone::None => 0,
            Tone::Acute => 1,
            Tone::Grave => 2,
            Tone::Hook => 3,
            Tone::Tilde => 4,
            Tone::Dot => 5,
        }
    }

    pub const fn from_index(i: usize) -> Tone {
        match i {
            1 => Tone::Acute,
            2 => Tone::Grave,
            3 => Tone::Hook,
            4 => Tone::Tilde,
            5 => Tone::Dot,
            _ => Tone::None,
        }
    }
}

/// Một chữ cái trong từ đang gõ. `base` luôn là chữ ASCII viết thường.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Letter {
    pub base: u8,
    pub mark: Mark,
    pub upper: bool,
}

impl Letter {
    pub const fn new(base: u8, mark: Mark, upper: bool) -> Letter {
        Letter { base, mark, upper }
    }

    /// Chữ thường lấy từ một phím ASCII.
    pub fn from_key(key: char) -> Letter {
        Letter {
            base: key.to_ascii_lowercase() as u8,
            mark: Mark::None,
            upper: key.is_ascii_uppercase(),
        }
    }

    pub const fn is_vowel(&self) -> bool {
        is_vowel_base(self.base)
    }

    /// Ghép chữ gốc, dấu phụ và thanh thành một ký tự Unicode dựng sẵn (NFC).
    pub fn render(&self, tone: Tone) -> char {
        if let Some(form) = vowel_form(self.base, self.mark) {
            let table = if self.upper { &VOWELS_UPPER } else { &VOWELS };
            return table[form][tone.index()];
        }
        let c = if self.base == b'd' && self.mark == Mark::Stroke {
            'đ'
        } else {
            self.base as char
        };
        if self.upper {
            if c == 'đ' {
                'Đ'
            } else {
                c.to_ascii_uppercase()
            }
        } else {
            c
        }
    }
}

pub const fn is_vowel_base(b: u8) -> bool {
    matches!(b, b'a' | b'e' | b'i' | b'o' | b'u' | b'y')
}

/// Vị trí của nguyên âm (kèm dấu phụ) trong bảng `VOWELS`.
pub const fn vowel_form(base: u8, mark: Mark) -> Option<usize> {
    match (base, mark) {
        (b'a', Mark::None) => Some(0),
        (b'a', Mark::Breve) => Some(1),
        (b'a', Mark::Circumflex) => Some(2),
        (b'e', Mark::None) => Some(3),
        (b'e', Mark::Circumflex) => Some(4),
        (b'i', _) => Some(5),
        (b'o', Mark::None) => Some(6),
        (b'o', Mark::Circumflex) => Some(7),
        (b'o', Mark::Horn) => Some(8),
        (b'u', Mark::None) => Some(9),
        (b'u', Mark::Horn) => Some(10),
        (b'y', _) => Some(11),
        _ => None,
    }
}

const FORM_BASE: [(u8, Mark); 12] = [
    (b'a', Mark::None),
    (b'a', Mark::Breve),
    (b'a', Mark::Circumflex),
    (b'e', Mark::None),
    (b'e', Mark::Circumflex),
    (b'i', Mark::None),
    (b'o', Mark::None),
    (b'o', Mark::Circumflex),
    (b'o', Mark::Horn),
    (b'u', Mark::None),
    (b'u', Mark::Horn),
    (b'y', Mark::None),
];

/// Thứ tự cột: không thanh, sắc, huyền, hỏi, ngã, nặng.
pub const VOWELS: [[char; 6]; 12] = [
    ['a', 'á', 'à', 'ả', 'ã', 'ạ'],
    ['ă', 'ắ', 'ằ', 'ẳ', 'ẵ', 'ặ'],
    ['â', 'ấ', 'ầ', 'ẩ', 'ẫ', 'ậ'],
    ['e', 'é', 'è', 'ẻ', 'ẽ', 'ẹ'],
    ['ê', 'ế', 'ề', 'ể', 'ễ', 'ệ'],
    ['i', 'í', 'ì', 'ỉ', 'ĩ', 'ị'],
    ['o', 'ó', 'ò', 'ỏ', 'õ', 'ọ'],
    ['ô', 'ố', 'ồ', 'ổ', 'ỗ', 'ộ'],
    ['ơ', 'ớ', 'ờ', 'ở', 'ỡ', 'ợ'],
    ['u', 'ú', 'ù', 'ủ', 'ũ', 'ụ'],
    ['ư', 'ứ', 'ừ', 'ử', 'ữ', 'ự'],
    ['y', 'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ'],
];

pub const VOWELS_UPPER: [[char; 6]; 12] = [
    ['A', 'Á', 'À', 'Ả', 'Ã', 'Ạ'],
    ['Ă', 'Ắ', 'Ằ', 'Ẳ', 'Ẵ', 'Ặ'],
    ['Â', 'Ấ', 'Ầ', 'Ẩ', 'Ẫ', 'Ậ'],
    ['E', 'É', 'È', 'Ẻ', 'Ẽ', 'Ẹ'],
    ['Ê', 'Ế', 'Ề', 'Ể', 'Ễ', 'Ệ'],
    ['I', 'Í', 'Ì', 'Ỉ', 'Ĩ', 'Ị'],
    ['O', 'Ó', 'Ò', 'Ỏ', 'Õ', 'Ọ'],
    ['Ô', 'Ố', 'Ồ', 'Ổ', 'Ỗ', 'Ộ'],
    ['Ơ', 'Ớ', 'Ờ', 'Ở', 'Ỡ', 'Ợ'],
    ['U', 'Ú', 'Ù', 'Ủ', 'Ũ', 'Ụ'],
    ['Ư', 'Ứ', 'Ừ', 'Ử', 'Ữ', 'Ự'],
    ['Y', 'Ý', 'Ỳ', 'Ỷ', 'Ỹ', 'Ỵ'],
];

/// Tách một ký tự thành chữ gốc ASCII, dấu phụ, thanh và chữ hoa.
/// Trả về `None` nếu không phải chữ cái Latin/tiếng Việt.
pub fn decompose(c: char) -> Option<(u8, Mark, Tone, bool)> {
    if c.is_ascii_alphabetic() {
        return Some((
            c.to_ascii_lowercase() as u8,
            Mark::None,
            Tone::None,
            c.is_ascii_uppercase(),
        ));
    }
    match c {
        'đ' => return Some((b'd', Mark::Stroke, Tone::None, false)),
        'Đ' => return Some((b'd', Mark::Stroke, Tone::None, true)),
        _ => {}
    }
    for (form, row) in VOWELS.iter().enumerate() {
        if let Some(t) = row.iter().position(|&x| x == c) {
            let (b, m) = FORM_BASE[form];
            return Some((b, m, Tone::from_index(t), false));
        }
    }
    for (form, row) in VOWELS_UPPER.iter().enumerate() {
        if let Some(t) = row.iter().position(|&x| x == c) {
            let (b, m) = FORM_BASE[form];
            return Some((b, m, Tone::from_index(t), true));
        }
    }
    None
}

/// Nguyên âm không thanh, dùng để so với bảng vần.
pub fn vowel_char(base: u8, mark: Mark) -> Option<char> {
    vowel_form(base, mark).map(|f| VOWELS[f][0])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn render_and_decompose_round_trip() {
        for (form, row) in VOWELS.iter().enumerate() {
            for (t, &c) in row.iter().enumerate() {
                let (b, m, tone, up) = decompose(c).unwrap();
                assert_eq!(vowel_form(b, m), Some(form));
                assert_eq!(tone.index(), t);
                assert!(!up);
                assert_eq!(Letter::new(b, m, false).render(tone), c);
                let cu = VOWELS_UPPER[form][t];
                assert_eq!(Letter::new(b, m, true).render(tone), cu);
            }
        }
        assert_eq!(
            Letter::new(b'd', Mark::Stroke, true).render(Tone::None),
            'Đ'
        );
    }
}
