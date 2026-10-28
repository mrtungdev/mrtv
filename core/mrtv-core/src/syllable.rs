//! Cấu trúc âm tiết tiếng Việt: âm đầu + vần (nguyên âm) + âm cuối.
//!
//! Dùng cho ba việc: tìm nguyên âm để đặt dấu, chọn chỗ đặt thanh,
//! và kiểm tra chữ đang gõ có còn là tiếng Việt hay không.

use crate::letters::{vowel_char, Letter, Mark, Tone};

/// Kiểu đặt thanh cho "oa", "oe", "uy" khi không có âm cuối.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum ToneStyle {
    /// hoà, hoè, thuỷ
    #[default]
    New,
    /// hòa, hòe, thủy
    Old,
}

/// Ranh giới các phần trong một từ: âm đầu `[0, onset_end)`,
/// vần `[onset_end, vowel_end)`, âm cuối `[vowel_end, len)`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Parts {
    pub onset_end: usize,
    pub vowel_end: usize,
}

pub fn split(letters: &[Letter]) -> Parts {
    let n = letters.len();
    let mut i = 0;
    while i < n && !letters[i].is_vowel() {
        i += 1;
    }
    let mut onset_end = i;
    if onset_end == 1 && i < n {
        let first = letters[0].base;
        let next = letters[i];
        // "qu": u thuộc âm đầu.
        if first == b'q' && next.base == b'u' {
            onset_end = 2;
        }
        // "gi" + nguyên âm khác: i thuộc âm đầu ("gia", "giờ"); "gì" thì không.
        if first == b'g' && next.base == b'i' && i + 1 < n && letters[i + 1].is_vowel() {
            onset_end = 2;
        }
    }
    let mut j = onset_end;
    while j < n && letters[j].is_vowel() {
        j += 1;
    }
    Parts {
        onset_end,
        vowel_end: j,
    }
}

const ONSETS: &[&str] = &[
    "b", "c", "ch", "d", "#", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh", "nh",
    "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
];

const CODAS: &[&str] = &["c", "ch", "m", "n", "ng", "nh", "p", "t"];

const CLUSTERS: &[&str] = &[
    "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y", "ai", "ao", "au", "ay", "âu", "ây",
    "eo", "êu", "ia", "iê", "iu", "oa", "oă", "oe", "oi", "ôi", "ơi", "oo", "ua", "uâ", "uê", "ui",
    "uô", "uơ", "uy", "ưa", "ưi", "ưu", "ươ", "yê", "iêu", "oai", "oao", "oay", "oeo", "uây",
    "uôi", "uya", "uyê", "uyu", "ươi", "ươu", "yêu",
];

/// Vần đi được với âm cuối. Vần tận cùng bằng bán âm (ai, ao, oi, ươi…) hay ia, ua, ưa thì không:
/// "boxing" không thành "boĩng".
const CODA_RHYMES: &[&str] = &[
    "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y", "iê", "yê", "oa", "oă", "oe", "oo",
    "uâ", "uê", "uô", "ươ", "uy", "uyê",
];

/// Vần phải có âm cuối mới thành chữ ("ăn", "tiên"; không có "tiê").
const NEED_CODA: &[&str] = &["ă", "â", "iê", "yê", "uô", "ươ", "oă", "uâ", "uyê", "oo"];

fn consonant_byte(l: &Letter) -> u8 {
    if l.base == b'd' && l.mark == Mark::Stroke {
        b'#'
    } else {
        l.base
    }
}

fn consonants_eq(letters: &[Letter], s: &str) -> bool {
    letters.len() == s.len()
        && letters
            .iter()
            .zip(s.bytes())
            .all(|(l, b)| consonant_byte(l) == b)
}

fn consonants_prefix_of(letters: &[Letter], s: &str) -> bool {
    letters.len() <= s.len()
        && letters
            .iter()
            .zip(s.bytes())
            .all(|(l, b)| consonant_byte(l) == b)
}

fn letter_matches(l: &Letter, p: char, exact: bool) -> bool {
    let Some(c) = vowel_char(l.base, l.mark) else {
        return false;
    };
    if c == p {
        return true;
    }
    if exact || l.mark != Mark::None {
        return false;
    }
    // Chữ chưa có dấu phụ khớp với chữ có dấu phụ cùng gốc: dấu có thể được thêm sau.
    vowel_char(l.base, Mark::None) == Some(base_of(p))
}

fn base_of(p: char) -> char {
    match p {
        'ă' | 'â' => 'a',
        'ê' => 'e',
        'ô' | 'ơ' => 'o',
        'ư' => 'u',
        c => c,
    }
}

fn cluster_matches(cluster: &[Letter], pattern: &str, exact: bool) -> bool {
    let len = pattern.chars().count();
    if exact && len != cluster.len() || len < cluster.len() {
        return false;
    }
    cluster
        .iter()
        .zip(pattern.chars())
        .all(|(l, p)| letter_matches(l, p, exact))
}

fn cluster_name<'a>(cluster: &[Letter]) -> Option<&'a str> {
    CLUSTERS
        .iter()
        .copied()
        .find(|p| cluster_matches(cluster, p, true))
}

fn letters_ok(letters: &[Letter]) -> bool {
    letters
        .iter()
        .all(|l| l.base.is_ascii_lowercase() && !matches!(l.base, b'f' | b'j' | b'w' | b'z'))
}

/// Chữ đang gõ còn có thể thành một âm tiết tiếng Việt hay không.
pub fn is_valid_prefix(letters: &[Letter]) -> bool {
    if letters.is_empty() {
        return true;
    }
    if !letters_ok(letters) {
        return false;
    }
    let p = split(letters);
    let onset = &letters[..p.onset_end];
    let cluster = &letters[p.onset_end..p.vowel_end];
    let coda = &letters[p.vowel_end..];
    if coda.iter().any(|l| l.is_vowel()) {
        return false;
    }
    if cluster.is_empty() {
        return onset.is_empty() || ONSETS.iter().any(|o| consonants_prefix_of(onset, o));
    }
    let onset_ok = onset.is_empty() || ONSETS.iter().any(|o| consonants_eq(onset, o));
    let cluster_ok = CLUSTERS.iter().any(|c| cluster_matches(cluster, c, false));
    // Đã có âm cuối thì vần đã đủ: phải là vần đi được với âm cuối, đúng độ dài.
    let coda_ok = coda.is_empty()
        || CODAS.iter().any(|c| consonants_prefix_of(coda, c))
            && CODA_RHYMES
                .iter()
                .any(|r| cluster_matches(cluster, r, false) && r.chars().count() == cluster.len());
    onset_ok && cluster_ok && coda_ok
}

/// Chữ đã là một âm tiết tiếng Việt trọn vẹn (dùng khi kết thúc từ).
pub fn is_complete(letters: &[Letter], tone: Tone) -> bool {
    if !is_valid_prefix(letters) {
        return false;
    }
    let p = split(letters);
    let onset = &letters[..p.onset_end];
    let cluster = &letters[p.onset_end..p.vowel_end];
    let coda = &letters[p.vowel_end..];
    if cluster.is_empty() || consonants_eq(onset, "q") {
        return false;
    }
    let Some(name) = cluster_name(cluster) else {
        return false;
    };
    if coda.is_empty() {
        return !NEED_CODA.contains(&name);
    }
    if !CODAS.iter().any(|c| consonants_eq(coda, c)) {
        return false;
    }
    let stop = ["c", "ch", "p", "t"].iter().any(|c| consonants_eq(coda, c));
    !stop || matches!(tone, Tone::Acute | Tone::Dot)
}

/// Vị trí đặt thanh trong vần (tính từ đầu vần).
pub fn tone_index(cluster: &[Letter], has_coda: bool, style: ToneStyle) -> usize {
    let n = cluster.len();
    if n <= 1 {
        return 0;
    }
    // "ươ": thanh nằm trên ơ.
    for i in 0..n - 1 {
        if cluster[i].base == b'u'
            && cluster[i + 1].base == b'o'
            && cluster[i + 1].mark == Mark::Horn
            && matches!(cluster[i].mark, Mark::Horn | Mark::None)
        {
            return i + 1;
        }
    }
    // Nguyên âm có dấu phụ luôn mang thanh.
    if let Some(i) = cluster
        .iter()
        .position(|l| matches!(l.mark, Mark::Circumflex | Mark::Breve | Mark::Horn))
    {
        return i;
    }
    if n >= 3 {
        return 1;
    }
    if has_coda {
        return 1;
    }
    let pair = (cluster[0].base, cluster[1].base);
    let glide_first = matches!(pair, (b'o', b'a') | (b'o', b'e') | (b'u', b'y'));
    if glide_first && style == ToneStyle::New {
        1
    } else {
        0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn word(s: &str) -> Vec<Letter> {
        s.chars()
            .map(|c| {
                let (b, m, _, up) = crate::letters::decompose(c).unwrap();
                Letter::new(b, m, up)
            })
            .collect()
    }

    #[test]
    fn prefixes() {
        for ok in [
            "ngh", "ngu", "nguye", "tiê", "tieng", "qu", "gi", "gia", "đươ", "khuya", "xoong",
            "quynh", "nguyen", "huênh", "ngoăn", "duong",
        ] {
            assert!(is_valid_prefix(&word(ok)), "{ok}");
        }
        for bad in [
            "good", "fa", "bôk", "sh", "tana", "hoâ", "web", "thx", "boin", "caing", "baic", "ươin",
        ] {
            assert!(!is_valid_prefix(&word(bad)), "{bad}");
        }
    }

    #[test]
    fn complete() {
        assert!(is_complete(&word("tiên"), Tone::None));
        assert!(!is_complete(&word("tiê"), Tone::None));
        assert!(is_complete(&word("tết"), Tone::Acute));
        assert!(!is_complete(&word("tet"), Tone::Grave));
        assert!(!is_complete(&word("ă"), Tone::None));
    }
}
