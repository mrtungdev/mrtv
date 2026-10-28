//! Bộ ca thử vàng: mỗi dòng là chuỗi phím và chữ phải ra.

use mrtv_core::{text, Config, Engine, Method, ToneStyle};

fn cases(tsv: &str) -> Vec<(String, String)> {
    tsv.lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(|l| {
            let (k, v) = l.split_once('\t').expect("thiếu dấu tab");
            (k.replace('_', " "), v.replace('_', " "))
        })
        .collect()
}

fn run(method: Method, tsv: &str) {
    let mut failed = Vec::new();
    for (keys, want) in cases(tsv) {
        let got = Engine::new(Config {
            method,
            ..Config::default()
        })
        .type_str(&keys);
        if got != want {
            failed.push(format!("{keys:?} → {got:?}, cần {want:?}"));
        }
    }
    assert!(
        failed.is_empty(),
        "{} ca sai:\n{}",
        failed.len(),
        failed.join("\n")
    );
}

#[test]
fn telex() {
    run(Method::Telex, include_str!("data/telex.tsv"));
}

#[test]
fn vni() {
    run(Method::Vni, include_str!("data/vni.tsv"));
}

#[test]
fn old_tone_style() {
    let cfg = Config {
        tone_style: ToneStyle::Old,
        ..Config::default()
    };
    for (keys, want) in [
        ("hoaf", "hòa"),
        ("thuyr", "thủy"),
        ("khoer", "khỏe"),
        ("toans", "toán"),
    ] {
        assert_eq!(Engine::new(cfg).type_str(keys), want);
    }
}

#[test]
fn simple_telex_keeps_w() {
    let cfg = Config {
        method: Method::SimpleTelex,
        ..Config::default()
    };
    assert_eq!(Engine::new(cfg).type_str("w"), "w");
    assert_eq!(Engine::new(cfg).type_str("uw"), "ư");
}

#[test]
fn encode_then_type_gives_same_word() {
    let words: Vec<String> = cases(include_str!("data/telex.tsv"))
        .into_iter()
        .map(|(_, w)| w.trim().to_string())
        .filter(|w| !w.is_ascii())
        .collect();
    for method in [Method::Telex, Method::Vni] {
        for w in &words {
            let keys = text::encode_keys(w, method);
            let got = Engine::new(Config {
                method,
                ..Config::default()
            })
            .type_str(&keys);
            assert_eq!(&got, w, "{method:?}: {keys:?}");
        }
    }
}

#[test]
fn macros_expand_on_space() {
    let mut e = Engine::default();
    e.set_macros(mrtv_core::macros::MacroTable::from_tsv(
        "ksao\tKhông sao đâu ạ",
    ));
    assert_eq!(e.type_str("ksao "), "Không sao đâu ạ ");
}

#[test]
fn english_words_keep_keys() {
    let mut failed = Vec::new();
    for w in include_str!("data/english-words.txt")
        .lines()
        .filter(|l| !l.starts_with('#'))
        .flat_map(str::split_whitespace)
    {
        let got = Engine::default().type_str(&format!("{w} "));
        if got.trim_end() != w {
            failed.push(format!("{w} → {got:?}"));
        }
    }
    assert!(
        failed.is_empty(),
        "{} từ sai:\n{}",
        failed.len(),
        failed.join("\n")
    );
}

#[test]
fn learned_exceptions_stay_english() {
    let mut e = Engine::default();
    e.set_exceptions(["test".to_string()]);
    assert_eq!(e.type_str("test "), "test ");
}
