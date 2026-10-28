//! Lõi gõ tiếng Việt của Mr TV.
//!
//! Không biết gì về giao diện hay macOS: nhận từng phím, trả về chỉnh sửa
//! cần làm trên chữ (số ký tự cần xoá + chữ cần chèn). Bộ gõ macOS (đường A)
//! và event tap (đường B) dùng chung lõi này.

pub mod charset;
pub mod engine;
mod input;
pub mod letters;
pub mod macros;
pub mod number;
pub mod syllable;
pub mod text;

pub use engine::{Config, Engine, Key, Method, Output, ToneStyle};

/// Phiên bản lõi, để giao diện hiện trong mục Giới thiệu.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
