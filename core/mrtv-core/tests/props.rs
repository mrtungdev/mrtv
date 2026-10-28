//! Thử ngẫu nhiên: không bao giờ hỏng, chữ ra luôn là Unicode dựng sẵn.

use mrtv_core::{text, Config, Engine, Method};
use proptest::prelude::*;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(2000))]

    #[test]
    fn telex_never_panics_and_is_nfc(input in "[a-zA-Z0-9 .,\u{8}\u{1b}]{0,40}") {
        let out = Engine::default().type_str(&input);
        prop_assert!(text::is_nfc(&out));
    }

    #[test]
    fn vni_never_panics_and_is_nfc(input in "[a-z0-9 \u{8}]{0,40}") {
        let out = Engine::new(Config { method: Method::Vni, ..Config::default() }).type_str(&input);
        prop_assert!(text::is_nfc(&out));
    }

    #[test]
    fn strip_is_idempotent(input in "\\PC{0,30}") {
        let once = text::strip_diacritics(&input);
        prop_assert_eq!(text::strip_diacritics(&once), once);
    }
}
