// SPDX-License-Identifier: MIT
// The Rust port must reproduce the outputs of the TS oracle bit for bit. Run
// `npm run goldens` first to write ../test/golden/fixmath.json.
use kohi_fixmath::fix64;
use serde_json::Value;
use std::fs;

fn i64s(v: &Value, key: &str) -> Vec<i64> {
    v[key].as_array().unwrap().iter().map(|s| s.as_str().unwrap().parse::<i64>().unwrap()).collect()
}
fn i128s(v: &Value, key: &str) -> Vec<i128> {
    v[key].as_array().unwrap().iter().map(|s| s.as_str().unwrap().parse::<i128>().unwrap()).collect()
}

#[test]
fn agrees_with_golden() {
    let s = fs::read_to_string("../test/golden/fixmath.json").expect("run `npm run goldens` first");
    let g: Value = serde_json::from_str(&s).unwrap();

    let binops: [(&str, fn(i64, i64) -> i64); 4] =
        [("add", fix64::add), ("sub", fix64::sub), ("mul", fix64::mul), ("div", fix64::div)];
    for (name, f) in binops {
        let (x, y, out) = (i64s(&g[name], "x"), i64s(&g[name], "y"), i64s(&g[name], "out"));
        for i in 0..out.len() {
            assert_eq!(f(x[i], y[i]), out[i], "{name}[{i}] x={} y={}", x[i], y[i]);
        }
    }

    let unops: [(&str, fn(i64) -> i64); 5] =
        [("abs", fix64::abs), ("sin", fix64::sin), ("cos", fix64::cos), ("exp", fix64::exp), ("sign", fix64::sign)];
    for (name, f) in unops {
        let (x, out) = (i64s(&g[name], "x"), i64s(&g[name], "out"));
        for i in 0..out.len() {
            assert_eq!(f(x[i]), out[i], "{name}[{i}] x={}", x[i]);
        }
    }

    let u128ops: [(&str, fn(i128) -> i128); 2] = [("log_256", fix64::log_256), ("log2_256", fix64::log2_256)];
    for (name, f) in u128ops {
        let (x, out) = (i128s(&g[name], "x"), i128s(&g[name], "out"));
        for i in 0..out.len() {
            assert_eq!(f(x[i]), out[i], "{name}[{i}] x={}", x[i]);
        }
    }
}
