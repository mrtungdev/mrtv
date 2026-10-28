//! Sinh header C `include/mrtv.h` từ mã Rust mỗi lần build.

fn main() {
    let dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=cbindgen.toml");
    let config =
        cbindgen::Config::from_file(format!("{dir}/cbindgen.toml")).expect("cbindgen.toml");
    cbindgen::Builder::new()
        .with_crate(&dir)
        .with_config(config)
        .generate()
        .expect("không sinh được mrtv.h")
        .write_to_file(format!("{dir}/include/mrtv.h"));
}
