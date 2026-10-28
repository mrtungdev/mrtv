//! Đo thời gian lõi xử lý mỗi phím. Mục tiêu: dưới 50 µs mỗi phím, thực tế nên dưới 2 µs.

use criterion::{black_box, criterion_group, criterion_main, Criterion, Throughput};
use mrtv_core::{Engine, Key};

const PARAGRAPH: &str =
    "Tooi ddang gox tieesng Vieejt baawng Mr TV, mootj booj gox mieexn phis vaf nhanh. \
Nguowif duf nhaats trong lowps hocj ddax ddeens truwowngf tuwf sowms. ";

fn typing(c: &mut Criterion) {
    let mut g = c.benchmark_group("typing");
    g.throughput(Throughput::Elements(PARAGRAPH.chars().count() as u64));
    g.bench_function("paragraph_telex", |b| {
        let mut e = Engine::default();
        b.iter(|| {
            for ch in PARAGRAPH.chars() {
                black_box(e.process(Key::Char(black_box(ch))));
            }
        })
    });
    g.finish();
}

criterion_group!(benches, typing);
criterion_main!(benches);
