// SPDX-License-Identifier: MIT
//
// This tool generates the agreement corpus for all languages from the TS oracle
// @kohi/fix64. It writes the same calculated vectors in two formats:
//   test/golden/fixmath.json   - decimal strings, for the Rust and TS checks
//   test/golden/abi/<fn>.hex   - abi.encode(int256[]...), for the Solidity test
// The Solidity and Rust ports must reproduce each output bit for bit.
import { mkdirSync, writeFileSync } from "node:fs";
import { encodeAbiParameters } from "viem";
import * as F from "../packages/fix64/src/index.js";

const ONE = F.ONE, PI = F.PI;

const vals: bigint[] = [
  0n, ONE, -ONE, F.TWO, -F.TWO, PI, -PI, F.PI_OVER_2,
  ONE / 2n, -ONE / 3n, ONE * 5n, -ONE * 7n, 12345678901n, -98765n, ONE / 1000n, ONE * 100n,
];
const angles: bigint[] = [];
for (let k = -16; k <= 16; k++) angles.push((PI * BigInt(k)) / 8n);
const expX: bigint[] = [];
for (let k = -10; k <= 10; k++) expX.push((ONE * BigInt(k)) / 2n);
const posVals: bigint[] = [ONE, F.TWO, PI, ONE * 10n, ONE * 100n, ONE * 1000n, ONE / 2n, 1n << 50n, 1n << 64n];

type Case = { kind: "bin" | "un"; x: bigint[]; y?: bigint[]; out: bigint[] };

function bin(f: (a: bigint, b: bigint) => bigint, xs: bigint[], ys: bigint[]): Case {
  const x: bigint[] = [], y: bigint[] = [], out: bigint[] = [];
  for (const a of xs) for (const b of ys) { try { const o = f(a, b); x.push(a); y.push(b); out.push(o); } catch { /* The input is out of the domain. */ } }
  return { kind: "bin", x, y, out };
}
function un(f: (a: bigint) => bigint, xs: bigint[]): Case {
  const x: bigint[] = [], out: bigint[] = [];
  for (const a of xs) { try { const o = f(a); x.push(a); out.push(o); } catch { /* The input is out of the domain. */ } }
  return { kind: "un", x, out };
}

const G: Record<string, Case> = {
  add: bin(F.add, vals, vals),
  sub: bin(F.sub, vals, vals),
  mul: bin(F.mul, vals, vals),
  div: bin(F.div, vals, vals.filter((v) => v !== 0n)),
  abs: un(F.abs, vals),
  sign: un(F.sign, vals),
  sin: un(F.sin, angles),
  cos: un(F.cos, angles),
  exp: un(F.exp, expX),
  log_256: un(F.log_256, posVals),
  log2_256: un(F.log2_256, posVals),
};

mkdirSync("test/golden/abi", { recursive: true });
const json: Record<string, unknown> = {};
for (const [name, c] of Object.entries(G)) {
  json[name] = c.kind === "bin"
    ? { kind: "bin", x: c.x.map(String), y: c.y!.map(String), out: c.out.map(String) }
    : { kind: "un", x: c.x.map(String), out: c.out.map(String) };
  const hex = c.kind === "bin"
    ? encodeAbiParameters([{ type: "int256[]" }, { type: "int256[]" }, { type: "int256[]" }], [c.x, c.y!, c.out])
    : encodeAbiParameters([{ type: "int256[]" }, { type: "int256[]" }], [c.x, c.out]);
  writeFileSync(`test/golden/abi/${name}.hex`, hex);
}
writeFileSync("test/golden/fixmath.json", JSON.stringify(json));
const total = Object.values(G).reduce((s, c) => s + c.out.length, 0);
console.log(`goldens written: ${Object.keys(G).length} functions, ${total} cases`);
