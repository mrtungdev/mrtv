//! Gõ tắt: gõ vài chữ rồi bấm dấu cách để ra cả câu.

use std::collections::HashMap;

#[derive(Clone, Debug, Default)]
pub struct MacroTable {
    map: HashMap<String, String>,
}

impl MacroTable {
    /// Đọc bảng dạng "chữ tắt<TAB>câu đầy đủ", mỗi dòng một mục. Dòng bắt đầu bằng # bị bỏ qua.
    pub fn from_tsv(text: &str) -> MacroTable {
        let mut map = HashMap::new();
        for line in text.lines() {
            let line = line.trim_end_matches('\r');
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((k, v)) = line.split_once('\t') {
                let k = k.trim();
                if !k.is_empty() && !v.is_empty() {
                    map.insert(k.to_lowercase(), v.to_string());
                }
            }
        }
        MacroTable { map }
    }

    pub fn insert(&mut self, key: &str, expansion: &str) {
        self.map.insert(key.to_lowercase(), expansion.to_string());
    }

    pub fn len(&self) -> usize {
        self.map.len()
    }

    pub fn is_empty(&self) -> bool {
        self.map.is_empty()
    }

    /// Bung chữ tắt theo kiểu chữ hoa của người gõ: ksao → Không sao…, KSAO → KHÔNG SAO…
    pub fn expand(&self, typed: &str) -> Option<String> {
        let exp = self.map.get(&typed.to_lowercase())?;
        let letters: Vec<char> = typed.chars().filter(|c| c.is_alphabetic()).collect();
        let all_upper = letters.len() > 1 && letters.iter().all(|c| c.is_uppercase());
        let first_upper = letters.first().is_some_and(|c| c.is_uppercase());
        Some(if all_upper {
            exp.to_uppercase()
        } else if first_upper {
            let mut cs = exp.chars();
            match cs.next() {
                Some(f) => f.to_uppercase().chain(cs).collect(),
                None => String::new(),
            }
        } else {
            exp.clone()
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn case_follows_typing() {
        let t = MacroTable::from_tsv("ksao\tkhông sao đâu ạ\n# ghi chú\nty\tCảm ơn nhiều!");
        assert_eq!(t.expand("ksao").as_deref(), Some("không sao đâu ạ"));
        assert_eq!(t.expand("Ksao").as_deref(), Some("Không sao đâu ạ"));
        assert_eq!(t.expand("KSAO").as_deref(), Some("KHÔNG SAO ĐÂU Ạ"));
        assert_eq!(t.expand("ty").as_deref(), Some("Cảm ơn nhiều!"));
        assert_eq!(t.expand("khac"), None);
    }
}
