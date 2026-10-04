// SPDX-License-Identifier: MIT
// Snapshot check: @kohi/fix64 generated the committed golden file. Thus, this
// check finds a later difference between the TS port and the frozen corpus.
import { readFileSync } from "node:fs";
import * as F from "../packages/fix64/src/index.js";

const g = JSON.parse(readFileSync("test/golden/fixmath.json", "utf8"));
let checked = 0, failed = 0;

const bin: Record<string, (a: bigint, b: bigint) => bigint> = { add: F.add, sub: F.sub, mul: F.mul, div: F.div };
const un: Record<string, (a: bigint) => bigint> = { abs: F.abs, sign: F.sign, sin: F.sin, cos: F.cos, exp: F.exp, log_256: F.log_256, log2_256: F.log2_256 };

for (const [name, f] of Object.entries(bin)) {
  const n = g[name];
  for (let i = 0; i < n.out.length; i++) {
    checked++;
    if (f(BigInt(n.x[i]), BigInt(n.y[i])) !== BigInt(n.out[i])) { failed++; console.error(`${name}[${i}] mismatch`); }
  }
}
for (const [name, f] of Object.entries(un)) {
  const n = g[name];
  for (let i = 0; i < n.out.length; i++) {
    checked++;
    if (f(BigInt(n.x[i])) !== BigInt(n.out[i])) { failed++; console.error(`${name}[${i}] mismatch`); }
  }
}
console.log(`TS agreement: ${checked} checked, ${failed} failed`);
process.exit(failed ? 1 : 0);
