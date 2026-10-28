//! Đọc số thành chữ: 1500 → "một nghìn năm trăm".

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum Thousand {
    #[default]
    Nghin,
    Ngan,
}

const DIGITS: [&str; 10] = [
    "không", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín",
];

fn read_triple(n: u64, full: bool, out: &mut Vec<&'static str>) {
    let (h, t, u) = (
        (n / 100) as usize,
        ((n / 10) % 10) as usize,
        (n % 10) as usize,
    );
    if full || h > 0 {
        out.push(DIGITS[h]);
        out.push("trăm");
    }
    match t {
        0 => {
            if u > 0 && (full || h > 0) {
                out.push("linh");
            }
        }
        1 => out.push("mười"),
        _ => {
            out.push(DIGITS[t]);
            out.push("mươi");
        }
    }
    match u {
        0 => {}
        1 if t >= 2 => out.push("mốt"),
        5 if t >= 1 => out.push("lăm"),
        _ => out.push(DIGITS[u]),
    }
}

/// Đọc một số tiền viết bằng chữ số: `1500000`, `1.500.000`, `1,500,000`, `1 500 000`, có thể kèm
/// dấu trừ và đơn vị (`đ`, `₫`, `VND`, `đồng`). Số lẻ (`1,5`, `1.5`, `12.345,67`) trả về `None`:
/// bỏ dấu phẩy đi là đổi giá trị, không được đoán.
pub fn parse_amount(s: &str) -> Option<i64> {
    let mut t = s.trim();
    let lower = t.to_lowercase();
    for unit in ["đồng", "vnđ", "vnd", "đ", "₫"] {
        if lower.ends_with(unit) {
            // Đơn vị đều không đổi độ dài khi viết thường, nên cắt theo độ dài của nó được.
            t = t[..t.len() - unit.len()].trim_end();
            break;
        }
    }
    let (neg, body) = match t.strip_prefix(['-', '−']) {
        Some(rest) => (true, rest.trim_start()),
        None => (false, t),
    };
    if body.is_empty() {
        return None;
    }
    let is_sep = |c: char| matches!(c, '.' | ',' | ' ' | '\u{a0}' | '\u{202f}');
    let sep = body.chars().find(|&c| is_sep(c));
    let groups: Vec<&str> = match sep {
        Some(sep) => body.split(sep).collect(),
        None => vec![body],
    };
    let digits_only = |g: &str| !g.is_empty() && g.bytes().all(|b| b.is_ascii_digit());
    let grouped =
        sep.is_none() || (groups[0].len() <= 3 && groups[1..].iter().all(|g| g.len() == 3));
    if !groups.iter().all(|g| digits_only(g)) || !grouped {
        return None;
    }
    let n: i64 = groups.concat().parse().ok()?;
    Some(if neg { -n } else { n })
}

/// Đọc một số nguyên (âm thì thêm "âm").
pub fn to_words(n: i64, thousand: Thousand) -> String {
    if n == 0 {
        return DIGITS[0].to_string();
    }
    let neg = n < 0;
    let mut v = n.unsigned_abs();
    let mut groups = Vec::new();
    while v > 0 {
        groups.push(v % 1000);
        v /= 1000;
    }
    let k = if thousand == Thousand::Ngan {
        "ngàn"
    } else {
        "nghìn"
    };
    let units: [&[&str]; 7] = [
        &[],
        &[k],
        &["triệu"],
        &["tỷ"],
        &[k, "tỷ"],
        &["triệu", "tỷ"],
        &["tỷ", "tỷ"],
    ];
    let mut words: Vec<&'static str> = Vec::new();
    if neg {
        words.push("âm");
    }
    let top = groups.len() - 1;
    for i in (0..groups.len()).rev() {
        let g = groups[i];
        if g == 0 {
            continue;
        }
        read_triple(g, i != top, &mut words);
        words.extend_from_slice(units[i]);
    }
    words.join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads() {
        let r = |n| to_words(n, Thousand::Nghin);
        assert_eq!(r(5), "năm");
        assert_eq!(r(15), "mười lăm");
        assert_eq!(r(21), "hai mươi mốt");
        assert_eq!(r(105), "một trăm linh năm");
        assert_eq!(r(1500), "một nghìn năm trăm");
        assert_eq!(r(1005), "một nghìn không trăm linh năm");
        assert_eq!(r(2_000_000), "hai triệu");
        assert_eq!(r(1_250_000), "một triệu hai trăm năm mươi nghìn");
        assert_eq!(to_words(3000, Thousand::Ngan), "ba ngàn");
        assert_eq!(r(-7), "âm bảy");
    }

    #[test]
    fn parses_amounts() {
        assert_eq!(parse_amount("1500000"), Some(1_500_000));
        assert_eq!(parse_amount("1.500.000"), Some(1_500_000));
        assert_eq!(parse_amount("1,500,000"), Some(1_500_000));
        assert_eq!(parse_amount("1 500 000"), Some(1_500_000));
        assert_eq!(parse_amount("1.500.000 đ"), Some(1_500_000));
        assert_eq!(parse_amount("250.000₫"), Some(250_000));
        assert_eq!(parse_amount("2.000 VND"), Some(2000));
        assert_eq!(parse_amount("-1.000"), Some(-1000));
        // Số lẻ hay dấu nhóm sai chỗ: không đoán.
        assert_eq!(parse_amount("1,5"), None);
        assert_eq!(parse_amount("1.5"), None);
        assert_eq!(parse_amount("12.345,67"), None);
        assert_eq!(parse_amount("1.50.000"), None);
        assert_eq!(parse_amount("1.500,000"), None);
        assert_eq!(parse_amount("12a"), None);
        assert_eq!(parse_amount(""), None);
        assert_eq!(parse_amount("đ"), None);
    }
}
