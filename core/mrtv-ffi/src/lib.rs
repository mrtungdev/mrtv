//! C ABI mỏng bọc `mrtv-core`.
//!
//! Đường gõ phím (`mrtv_engine_key`) không cấp phát bộ nhớ và không chép chữ:
//! con trỏ `text` trỏ vào bộ đệm của engine, dùng được tới lần gọi kế tiếp.
//! Mọi hàm đều bắt panic, để lỗi trong lõi không làm sập bộ gõ: khi có lỗi,
//! phím được để đi tiếp như bình thường.

use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use mrtv_core::charset::{self, Charset};
use mrtv_core::macros::MacroTable;
use mrtv_core::number::{self, Thousand};
use mrtv_core::{text, Config, Engine, Key, Method, ToneStyle};

/// Kiểu gõ.
pub const MRTV_METHOD_TELEX: u32 = 0;
pub const MRTV_METHOD_SIMPLE_TELEX: u32 = 1;
pub const MRTV_METHOD_VNI: u32 = 2;

/// Kiểu đặt dấu: hoà (mới) hay hòa (cũ).
pub const MRTV_TONE_NEW: u32 = 0;
pub const MRTV_TONE_OLD: u32 = 1;

/// Phím đặc biệt cho `mrtv_engine_key`.
pub const MRTV_KEY_BACKSPACE: u32 = 0x08;
pub const MRTV_KEY_ESCAPE: u32 = 0x1B;

/// Việc của `mrtv_text`.
pub const MRTV_TEXT_NFC: u32 = 1;
pub const MRTV_TEXT_STRIP: u32 = 2;
pub const MRTV_TEXT_SLUG: u32 = 3;
pub const MRTV_TEXT_UPPER: u32 = 4;
pub const MRTV_TEXT_LOWER: u32 = 5;
pub const MRTV_TEXT_TITLE: u32 = 6;
pub const MRTV_TEXT_SENTENCE: u32 = 7;
pub const MRTV_TEXT_FROM_VIQR: u32 = 8;
pub const MRTV_TEXT_FROM_TCVN3: u32 = 9;
pub const MRTV_TEXT_REVERSE_TELEX: u32 = 10;
pub const MRTV_TEXT_REVERSE_VNI: u32 = 11;
/// `arg`: 0 = nghìn, 1 = ngàn. Đầu vào là chuỗi chữ số.
pub const MRTV_TEXT_NUMBER_WORDS: u32 = 12;
/// Trả về "1" nếu chữ trông như TCVN3 dán nhầm, "0" nếu không.
pub const MRTV_TEXT_LOOKS_TCVN3: u32 = 13;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MrtvConfig {
    pub method: u32,
    pub tone_style: u32,
    pub restore_english: bool,
    pub macros_enabled: bool,
}

#[repr(C)]
pub struct MrtvOutput {
    /// false: để phím đi tiếp (sau khi áp chỉnh sửa, nếu có).
    pub consumed: bool,
    /// Số ký tự cần xoá ngay trước con trỏ (số lần bấm phím xoá).
    pub backspaces: u32,
    /// Như `backspaces` nhưng tính theo đơn vị UTF-16, cho nơi xoá theo khoảng (NSRange).
    pub deleted_utf16: u32,
    /// Số lần bấm phím xoá thật (đường gõ đè): emoji ghép nhiều ký tự chỉ tính một lần.
    pub delete_keys: u32,
    /// Chữ UTF-16 cần chèn; có hiệu lực tới lần gọi kế tiếp.
    pub text: *const u16,
    pub text_len: u32,
}

/// Bộ máy gõ, một cái cho mỗi bộ gõ đang chạy.
pub struct MrtvEngine {
    inner: Engine,
}

fn to_config(c: &MrtvConfig) -> Config {
    Config {
        method: match c.method {
            MRTV_METHOD_VNI => Method::Vni,
            MRTV_METHOD_SIMPLE_TELEX => Method::SimpleTelex,
            _ => Method::Telex,
        },
        tone_style: if c.tone_style == MRTV_TONE_OLD {
            ToneStyle::Old
        } else {
            ToneStyle::New
        },
        restore_english: c.restore_english,
        macros_enabled: c.macros_enabled,
    }
}

const PASS: MrtvOutput = MrtvOutput {
    consumed: false,
    backspaces: 0,
    deleted_utf16: 0,
    delete_keys: 0,
    text: ptr::null(),
    text_len: 0,
};

unsafe fn str_arg<'a>(s: *const c_char) -> Option<&'a str> {
    if s.is_null() {
        return None;
    }
    CStr::from_ptr(s).to_str().ok()
}

/// Tạo bộ máy gõ. `config` có thể là NULL (dùng mặc định: Telex, dấu kiểu mới).
///
/// # Safety
/// `config` phải là NULL hoặc trỏ tới một `MrtvConfig` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_new(config: *const MrtvConfig) -> *mut MrtvEngine {
    let cfg = if config.is_null() {
        Config::default()
    } else {
        to_config(&*config)
    };
    catch_unwind(|| {
        Box::into_raw(Box::new(MrtvEngine {
            inner: Engine::new(cfg),
        }))
    })
    .unwrap_or(ptr::null_mut())
}

/// # Safety
/// `engine` phải do `mrtv_engine_new` tạo và chưa bị giải phóng.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_free(engine: *mut MrtvEngine) {
    if !engine.is_null() {
        drop(Box::from_raw(engine));
    }
}

/// # Safety
/// Con trỏ phải hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_set_config(
    engine: *mut MrtvEngine,
    config: *const MrtvConfig,
) {
    if engine.is_null() || config.is_null() {
        return;
    }
    let cfg = to_config(&*config);
    let e = &mut *engine;
    let _ = catch_unwind(AssertUnwindSafe(|| e.inner.set_config(cfg)));
}

/// Bỏ từ đang gõ (khi bấm chuột, phím mũi tên, đổi ứng dụng…).
///
/// # Safety
/// `engine` phải hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_reset(engine: *mut MrtvEngine) {
    if let Some(e) = engine.as_mut() {
        let _ = catch_unwind(AssertUnwindSafe(|| e.inner.reset()));
    }
}

/// Xử lý một phím. `codepoint` là ký tự phím gõ ra, hoặc `MRTV_KEY_BACKSPACE` / `MRTV_KEY_ESCAPE`.
///
/// # Safety
/// `engine` phải hợp lệ. Không gọi đồng thời từ nhiều luồng trên cùng một engine.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_key(engine: *mut MrtvEngine, codepoint: u32) -> MrtvOutput {
    let Some(e) = engine.as_mut() else {
        return PASS;
    };
    let key = match codepoint {
        MRTV_KEY_BACKSPACE => Key::Backspace,
        MRTV_KEY_ESCAPE => Key::Escape,
        cp => match char::from_u32(cp) {
            Some(c) => Key::Char(c),
            None => return PASS,
        },
    };
    let result = catch_unwind(AssertUnwindSafe(|| {
        let out = e.inner.process(key);
        let ins = e.inner.insert();
        MrtvOutput {
            consumed: out.consumed,
            backspaces: out.backspaces,
            deleted_utf16: out.deleted_utf16,
            delete_keys: out.delete_keys,
            text: if ins.is_empty() {
                ptr::null()
            } else {
                ins.as_ptr()
            },
            text_len: ins.len() as u32,
        }
    }));
    match result {
        Ok(o) => o,
        Err(_) => {
            e.inner.reset();
            PASS
        }
    }
}

/// Từ đang gõ (UTF-16), cho chữ đang soạn của bộ gõ chuẩn. Có hiệu lực tới lần gọi kế tiếp.
///
/// # Safety
/// `engine` và `out_len` phải hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_word(
    engine: *mut MrtvEngine,
    out_len: *mut u32,
) -> *const u16 {
    let Some(e) = engine.as_mut() else {
        return ptr::null();
    };
    let w = e.inner.current_word();
    if !out_len.is_null() {
        *out_len = w.len() as u32;
    }
    w.as_ptr()
}

/// Nạp bảng gõ tắt dạng "chữ tắt<TAB>câu đầy đủ", mỗi dòng một mục (UTF-8).
///
/// # Safety
/// `engine` hợp lệ, `tsv` là chuỗi C UTF-8 hoặc NULL.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_set_macros(engine: *mut MrtvEngine, tsv: *const c_char) {
    if let (Some(e), Some(s)) = (engine.as_mut(), str_arg(tsv)) {
        let _ = catch_unwind(AssertUnwindSafe(|| {
            e.inner.set_macros(MacroTable::from_tsv(s))
        }));
    }
}

/// Nạp danh sách từ luôn giữ nguyên (mỗi dòng một từ), học từ những lần bấm esc.
///
/// # Safety
/// `engine` hợp lệ, `lines` là chuỗi C UTF-8 hoặc NULL.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_set_exceptions(engine: *mut MrtvEngine, lines: *const c_char) {
    if let (Some(e), Some(s)) = (engine.as_mut(), str_arg(lines)) {
        let words: Vec<String> = s
            .lines()
            .map(str::trim)
            .filter(|l| !l.is_empty())
            .map(String::from)
            .collect();
        let _ = catch_unwind(AssertUnwindSafe(|| e.inner.set_exceptions(words)));
    }
}

/// Con trỏ vừa tới cuối một từ có sẵn: `before` là chữ ngay trước con trỏ. Lấy từ đó làm từ đang gõ.
///
/// # Safety
/// `engine` hợp lệ, `before` là chuỗi C UTF-8 hoặc NULL.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_resume(engine: *mut MrtvEngine, before: *const c_char) {
    if let (Some(e), Some(s)) = (engine.as_mut(), str_arg(before)) {
        let _ = catch_unwind(AssertUnwindSafe(|| e.inner.resume(s)));
    }
}

/// Nạp danh sách từ tiếng Anh có sẵn mà người dùng đã tắt (mỗi dòng một từ).
///
/// # Safety
/// `engine` hợp lệ, `lines` là chuỗi C UTF-8 hoặc NULL.
#[no_mangle]
pub unsafe extern "C" fn mrtv_engine_set_english_off(
    engine: *mut MrtvEngine,
    lines: *const c_char,
) {
    if let (Some(e), Some(s)) = (engine.as_mut(), str_arg(lines)) {
        let words: Vec<String> = s
            .lines()
            .map(str::trim)
            .filter(|l| !l.is_empty())
            .map(String::from)
            .collect();
        let _ = catch_unwind(AssertUnwindSafe(|| e.inner.set_english_off(words)));
    }
}

/// Danh sách từ tiếng Anh có sẵn, mỗi dòng một từ. Giải phóng bằng `mrtv_string_free`.
#[no_mangle]
pub extern "C" fn mrtv_english_list() -> *mut c_char {
    CString::new(text::english_list().join("\n"))
        .map(CString::into_raw)
        .unwrap_or(ptr::null_mut())
}

/// Chạy một việc trên chữ (bỏ dấu, đổi bảng mã, chuyển ngược…). Trả về chuỗi C mới,
/// phải giải phóng bằng `mrtv_string_free`. NULL nếu đầu vào sai.
///
/// # Safety
/// `input` là chuỗi C UTF-8.
#[no_mangle]
pub unsafe extern "C" fn mrtv_text(op: u32, input: *const c_char, arg: u32) -> *mut c_char {
    let Some(s) = str_arg(input) else {
        return ptr::null_mut();
    };
    let out = catch_unwind(|| match op {
        MRTV_TEXT_NFC => Some(text::nfc(s)),
        MRTV_TEXT_STRIP => Some(text::strip_diacritics(s)),
        MRTV_TEXT_SLUG => Some(text::slug(s)),
        MRTV_TEXT_UPPER => Some(text::upper(s)),
        MRTV_TEXT_LOWER => Some(text::lower(s)),
        MRTV_TEXT_TITLE => Some(text::title(s)),
        MRTV_TEXT_SENTENCE => Some(text::sentence(s)),
        MRTV_TEXT_FROM_VIQR => Some(charset::to_unicode(s, Charset::Viqr)),
        MRTV_TEXT_FROM_TCVN3 => Some(charset::to_unicode(s, Charset::Tcvn3)),
        MRTV_TEXT_REVERSE_TELEX => Some(text::reverse(s, Method::Telex)),
        MRTV_TEXT_REVERSE_VNI => Some(text::reverse(s, Method::Vni)),
        MRTV_TEXT_NUMBER_WORDS => {
            let thousand = if arg == 1 {
                Thousand::Ngan
            } else {
                Thousand::Nghin
            };
            number::parse_amount(s).map(|n| number::to_words(n, thousand))
        }
        MRTV_TEXT_LOOKS_TCVN3 => Some(
            if charset::looks_like_tcvn3(s) {
                "1"
            } else {
                "0"
            }
            .to_string(),
        ),
        _ => None,
    });
    match out {
        Ok(Some(v)) => CString::new(v)
            .map(CString::into_raw)
            .unwrap_or(ptr::null_mut()),
        _ => ptr::null_mut(),
    }
}

/// # Safety
/// `s` phải do `mrtv_text` trả về, hoặc NULL.
#[no_mangle]
pub unsafe extern "C" fn mrtv_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

/// Phiên bản lõi, ví dụ "0.1.0". Chuỗi tĩnh, không cần giải phóng.
#[no_mangle]
pub extern "C" fn mrtv_version() -> *const c_char {
    static V: &[u8] = concat!(env!("CARGO_PKG_VERSION"), "\0").as_bytes();
    V.as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn typing_through_c_abi() {
        unsafe {
            let e = mrtv_engine_new(ptr::null());
            let mut screen = String::new();
            for c in "Vieejt ".chars() {
                let o = mrtv_engine_key(e, c as u32);
                for _ in 0..o.backspaces {
                    screen.pop();
                }
                if o.text_len > 0 {
                    let s = std::slice::from_raw_parts(o.text, o.text_len as usize);
                    screen.push_str(&String::from_utf16_lossy(s));
                }
                if !o.consumed {
                    screen.push(c);
                }
            }
            assert_eq!(screen, "Việt ");
            mrtv_engine_free(e);

            let input = CString::new("Tiếng Việt").unwrap();
            let out = mrtv_text(MRTV_TEXT_SLUG, input.as_ptr(), 0);
            assert_eq!(CStr::from_ptr(out).to_str().unwrap(), "tieng-viet");
            mrtv_string_free(out);
        }
    }
}
