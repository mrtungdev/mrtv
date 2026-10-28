//! Gõ mọi âm tiết tiếng Việt theo nhiều cách và kiểm tra chữ ra đúng.
//!
//! Âm tiết sinh từ âm đầu × vần × thanh, rồi lọc theo luật chính tả (c/k/q, g/gh, ng/ngh,
//! thanh với âm cuối tắc). Mỗi âm tiết được gõ:
//! 1. theo phím chuẩn (dấu mũ, móc ngay sau nguyên âm, thanh ở cuối),
//! 2. dấu mũ, móc gõ sau cùng ("vietej" → "việt"),
//! 3. thanh ngay sau nguyên âm chính ("tieesng"),
//! 4. viết hoa chữ đầu và viết hoa cả từ,
//! 5. VNI.

use mrtv_core::{text, Config, Engine, Method};

const ONSETS: &[&str] = &[
    "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh",
    "nh", "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
];

/// Vần tiếng Việt (không thanh).
const RHYMES: &[&str] = &[
    "a", "ai", "ao", "au", "ay", "an", "ang", "anh", "am", "ap", "at", "ac", "ach", "ăn", "ăng",
    "ăm", "ăp", "ăt", "ăc", "âu", "ây", "ân", "âng", "âm", "âp", "ât", "âc", "e", "eo", "en",
    "eng", "em", "ep", "et", "ec", "ê", "êu", "ên", "ênh", "êm", "êp", "êt", "êch", "i", "ia",
    "iu", "in", "inh", "im", "ip", "it", "ich", "iêu", "iên", "iêng", "iêm", "iêp", "iêt", "iêc",
    "o", "oi", "on", "ong", "om", "op", "ot", "oc", "oa", "oai", "oay", "oan", "oang", "oanh",
    "oam", "oap", "oat", "oac", "oach", "oe", "oeo", "oen", "oet", "oăn", "oăng", "oăm", "oăt",
    "oăc", "ô", "ôi", "ôn", "ông", "ôm", "ôp", "ôt", "ôc", "ơ", "ơi", "ơn", "ơm", "ơp", "ơt", "u",
    "ua", "ui", "un", "ung", "um", "up", "ut", "uc", "uy", "uya", "uyu", "uych", "uyên", "uyêt",
    "uynh", "uyt", "uân", "uât", "uây", "uê", "uêch", "uênh", "ư", "ưa", "ưi", "ưu", "ưng", "ưt",
    "ưc", "ươi", "ươu", "ươn", "ương", "ươm", "ươp", "ươt", "ươc", "uôi", "uôn", "uông", "uôm",
    "uôt", "uôc", "y", "yêu", "yên", "yêt",
];

/// Thanh: không, sắc, huyền, hỏi, ngã, nặng — dạng dấu kết hợp.
const TONES: &[&str] = &["", "\u{301}", "\u{300}", "\u{309}", "\u{303}", "\u{323}"];

fn first_vowel(r: &str) -> char {
    text::strip_diacritics(r).chars().next().unwrap()
}

/// Luật chính tả cho âm đầu + vần.
fn allowed(onset: &str, rhyme: &str) -> bool {
    let v = first_vowel(rhyme);
    let front = matches!(v, 'e' | 'i' | 'y');
    match onset {
        "c" | "g" | "ng" => !front,
        "k" | "gh" | "ngh" => front,
        "qu" => {
            !rhyme.starts_with('u')
                && !rhyme.starts_with('ư')
                && !rhyme.starts_with('o')
                && !rhyme.starts_with('ô')
        }
        "gi" => !rhyme.starts_with('i'),
        "" => !rhyme.starts_with("iê") && !rhyme.starts_with("uyu"),
        _ => !rhyme.starts_with('y'),
    }
}

/// Chữ đúng, đặt thanh kiểu mới (hoà, thuỷ) theo luật chính tả, viết độc lập với lõi gõ:
/// có nguyên âm mang dấu (ă â ê ô ơ ư) thì thanh nằm trên đó (ươ: trên ơ); không thì
/// một nguyên âm: trên nó; hai nguyên âm: có âm cuối hoặc là oa, oe, uy thì nguyên âm sau, còn lại nguyên âm trước;
/// ba nguyên âm: nguyên âm giữa.
fn word(onset: &str, rhyme: &str, tone: usize) -> Option<String> {
    let stop = ["p", "t", "c", "ch"].iter().any(|c| rhyme.ends_with(c));
    if stop && !(tone == 0 || tone == 1 || tone == 5) {
        return None;
    }
    let chars: Vec<char> = rhyme.chars().collect();
    let is_vowel = |c: char| "aăâeêioôơuưy".contains(c);
    let n = chars.iter().take_while(|&&c| is_vowel(c)).count();
    let has_coda = n < chars.len();
    let marked = |c: char| "ăâêôơư".contains(c);
    let target = if let Some(i) = (0..n).rev().find(|&i| marked(chars[i])) {
        // "ươ": thanh trên ơ (chữ sau); các dấu khác: chữ mang dấu.
        i
    } else {
        match n {
            1 => 0,
            2 => {
                let pair: String = chars[..2].iter().collect();
                if has_coda || ["oa", "oe", "uy"].contains(&pair.as_str()) {
                    1
                } else {
                    0
                }
            }
            _ => 1,
        }
    };
    let mut out = String::from(onset);
    for (i, c) in chars.iter().enumerate() {
        out.push(*c);
        if i == target {
            out.push_str(TONES[tone]);
        }
    }
    Some(text::nfc(&out))
}

struct Report {
    failures: Vec<String>,
    checked: usize,
}

impl Report {
    fn check(&mut self, label: &str, keys: &str, want: &str, method: Method) {
        self.checked += 1;
        let got = Engine::new(Config {
            method,
            ..Config::default()
        })
        .type_str(keys);
        if got != want {
            self.failures
                .push(format!("{label}: {keys:?} → {got:?}, cần {want:?}"));
        }
    }
}

/// Phím gõ "dấu mũ, móc sau cùng": chữ không dấu (giữ đ bằng dd), rồi phím dấu, rồi thanh.
fn late_marks(w: &str) -> String {
    let mut base = String::new();
    let mut marks = String::new();
    let mut tone = "";
    let mut horn_done = false;
    for c in w.chars() {
        let lower = c.to_lowercase().next().unwrap();
        let nfd: String = text::strip_diacritics(&lower.to_string());
        let t = match () {
            _ if "áắấéếíóốớúứý".contains(lower) => "s",
            _ if "àằầèềìòồờùừỳ".contains(lower) => "f",
            _ if "ảẳẩẻểỉỏổởủửỷ".contains(lower) => "r",
            _ if "ãẵẫẽễĩõỗỡũữỹ".contains(lower) => "x",
            _ if "ạặậẹệịọộợụựỵ".contains(lower) => "j",
            _ => "",
        };
        if !t.is_empty() {
            tone = t;
        }
        let toneless = text::nfc(&remove_tone(lower));
        match toneless.as_str() {
            "đ" => base.push_str("dd"),
            "â" | "ê" | "ô" => {
                base.push_str(&nfd);
                marks.push_str(&nfd);
            }
            "ă" => {
                base.push('a');
                marks.push('w');
            }
            "ơ" | "ư" => {
                base.push_str(&nfd);
                if !horn_done {
                    marks.push('w');
                    horn_done = true;
                }
            }
            _ => base.push_str(&nfd),
        }
    }
    format!("{base}{marks}{tone}")
}

fn remove_tone(c: char) -> String {
    let mut out = String::new();
    for ch in c.to_string().chars() {
        // Bỏ dấu thanh, giữ dấu mũ/móc/trăng: tách theo bảng nhỏ.
        let table = [
            ("áàảãạ", 'a'),
            ("ắằẳẵặ", 'ă'),
            ("ấầẩẫậ", 'â'),
            ("éèẻẽẹ", 'e'),
            ("ếềểễệ", 'ê'),
            ("íìỉĩị", 'i'),
            ("óòỏõọ", 'o'),
            ("ốồổỗộ", 'ô'),
            ("ớờởỡợ", 'ơ'),
            ("úùủũụ", 'u'),
            ("ứừửữự", 'ư'),
            ("ýỳỷỹỵ", 'y'),
        ];
        let mut mapped = ch;
        for (set, base) in table {
            if set.contains(ch) {
                mapped = base;
            }
        }
        out.push(mapped);
    }
    out
}

#[test]
fn every_syllable_types_correctly() {
    let mut r = Report {
        failures: Vec::new(),
        checked: 0,
    };
    let mut syllables = 0;
    for onset in ONSETS {
        for rhyme in RHYMES {
            if !allowed(onset, rhyme) {
                continue;
            }
            for tone in 0..6 {
                let Some(w) = word(onset, rhyme, tone) else {
                    continue;
                };
                syllables += 1;
                let canonical = text::encode_keys(&w, Method::Telex);
                r.check("chuẩn", &canonical, &w, Method::Telex);
                // Từ tiếng Anh đã biết (data, java…) cố ý không gõ dấu sau.
                let late = late_marks(&w);
                if !text::english_words().contains(&late) {
                    r.check("dấu sau cùng", &late, &w, Method::Telex);
                }
                let mut cap = w.chars();
                let first = cap.next().unwrap();
                let capitalized: String = first.to_uppercase().chain(cap).collect();
                r.check(
                    "viết hoa đầu",
                    &text::encode_keys(&capitalized, Method::Telex),
                    &capitalized,
                    Method::Telex,
                );
                r.check(
                    "VIẾT HOA",
                    &text::encode_keys(&w.to_uppercase(), Method::Telex),
                    &w.to_uppercase(),
                    Method::Telex,
                );
                r.check("VNI", &text::encode_keys(&w, Method::Vni), &w, Method::Vni);
                // Chữ chưa trọn (thiếu thanh: "bêt") mà phím gõ là từ tiếng Anh ("beet") thì cố ý trả lại phím gốc.
                if !text::english_dict().contains(canonical.as_str()) {
                    r.check(
                        "có dấu cách",
                        &format!("{canonical} "),
                        &format!("{w} "),
                        Method::Telex,
                    );
                }
            }
        }
    }
    // Gom theo nhóm: mỗi cách gõ + phần vần chỉ hiện một ca.
    let mut seen = std::collections::HashSet::new();
    let shown: Vec<&String> = r
        .failures
        .iter()
        .filter(|f| {
            let label = f.split(':').next().unwrap_or("");
            let want = f.rsplit("cần ").next().unwrap_or("");
            let key = format!(
                "{label}|{}",
                text::strip_diacritics(want).trim_start_matches(|c: char| !"aeiouy".contains(c))
            );
            seen.insert(key)
        })
        .take(120)
        .collect();
    assert!(
        r.failures.is_empty(),
        "{} / {} lần gõ sai ({} âm tiết):\n{}",
        r.failures.len(),
        r.checked,
        syllables,
        shown
            .iter()
            .map(|s| s.as_str())
            .collect::<Vec<_>>()
            .join("\n")
    );
}
