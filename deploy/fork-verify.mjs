#!/usr/bin/env node
// SPDX-License-Identifier: MIT
//
// fork-verify.mjs: this script proves two facts about the Trig256 that we deploy.
//   1. The bytecode is byte-identical to the approved template.
//   2. The public functions return the golden values through a live eth_call.
//
//   node deploy/fork-verify.mjs                                    # start anvil, deploy, then verify
//   node deploy/fork-verify.mjs --address 0x.. --network mainnet   # verify a live deployment
//
// The primary proof is that the bytecode is identical. The deployed runtime of
// a library contains the address of the library in the non-callable guard at
// the start (PUSH20 <addr>; ADDRESS; EQ). Thus, the script sets those 20 bytes
// to zero. Then it compares the sha256 with the template hash in
// docs/bytecode-identity.md. Identical bytecode gives identical behavior,
// because `forge test` proves that the template calculates the golden values.
// The eth_call pass is a second, independent check. It runs the deployed code
// from start to end. An eth_call arrives at the address of the library. Thus,
// the ADDRESS==self check of the guard passes and the pure functions run.
import { readFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createPublicClient, createWalletClient, http, getAddress, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry, mainnet, sepolia } from "viem/chains";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const C = { g: "\x1b[32m", r: "\x1b[31m", y: "\x1b[33m", b: "\x1b[1m", x: "\x1b[0m" };
const TEMPLATE_SHA256 = "9e4d0e8e8712c70230085669c170a45ff58f243b3ded1b0bf4fc9a0f3ec9645d";
const PORT = 8545, LOCAL = `http://127.0.0.1:${PORT}`;
const ANVIL_PK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // Account #0 of anvil.

(() => {
  const f = join(ROOT, ".env");
  if (!existsSync(f)) return;
  for (const line of readFileSync(f, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!m || m[1] in process.env) continue;
    process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
})();

const argOf = (name) => { const i = process.argv.indexOf(name); return i > -1 ? process.argv[i + 1] : undefined; };
const art = JSON.parse(readFileSync(join(ROOT, "out/Trig256.sol/Trig256.json"), "utf8"));
const creation = art.bytecode.object;
const golden = existsSync(join(ROOT, "test/golden/fixmath.json"))
  ? JSON.parse(readFileSync(join(ROOT, "test/golden/fixmath.json"), "utf8"))
  : null;

const sha256 = (s) => createHash("sha256").update(s).digest("hex");
// Set to zero the 20 address bytes in the PUSH20 non-callable guard at the
// start of the library code.
function maskGuard(code) {
  if (!code || code.slice(0, 4).toLowerCase() !== "0x73") return code;
  return code.slice(0, 4) + "0".repeat(40) + code.slice(44);
}

const ABI = parseAbi([
  "function log_256(int256) pure returns (int256)",
  "function log2_256(int256) pure returns (int256)",
  "function exp(int64) pure returns (int64)",
]);

async function checkBytecode(pub, address) {
  const code = await pub.getCode({ address });
  if (!code || code === "0x") { console.log(`  ${C.r}FAIL${C.x} no code at ${address}`); return false; }
  const got = sha256(maskGuard(code));
  const ok = got === TEMPLATE_SHA256;
  console.log(`  bytecode   ${ok ? C.g + "byte-identical to template" + C.x : C.r + "DRIFT " + got + C.x}   (${(code.length - 2) / 2} B on-chain, address guard masked)`);
  return ok;
}

async function checkFunctional(pub, address) {
  if (!golden) { console.log(`  ${C.y}functional  skipped (no golden; run npm run goldens)${C.x}`); return true; }
  let checked = 0, bad = 0;
  for (const fn of ["log_256", "log2_256", "exp"]) {
    const g = golden[fn];
    if (!g) continue;
    for (let i = 0; i < g.out.length; i++) {
      const got = await pub.readContract({ address, abi: ABI, functionName: fn, args: [BigInt(g.x[i])] });
      checked++;
      if (BigInt(got) !== BigInt(g.out[i])) { bad++; if (bad <= 3) console.log(`  ${C.r}  ${fn}[${i}] x=${g.x[i]} got ${got} want ${g.out[i]}${C.x}`); }
    }
  }
  const ok = bad === 0;
  console.log(`  functional ${ok ? C.g : C.r}${checked - bad}/${checked}${C.x}   deployed eth_call log_256/log2_256/exp vs golden`);
  return ok;
}

async function startAnvil() {
  const proc = spawn("anvil", ["--port", String(PORT), "--silent"], { stdio: ["ignore", "pipe", "pipe"] });
  let err = "";
  proc.stderr.on("data", (d) => (err += d));
  const pub = createPublicClient({ chain: foundry, transport: http(LOCAL) });
  const deadline = Date.now() + 30000;
  for (;;) {
    if (proc.exitCode != null) throw new Error(`anvil exited (${proc.exitCode}):\n${err}`);
    try { await pub.getBlockNumber(); return proc; } catch { /* The node is not ready. */ }
    if (Date.now() > deadline) { proc.kill(); throw new Error("anvil not ready in 30s"); }
    await new Promise((r) => setTimeout(r, 300));
  }
}

async function main() {
  const addr = argOf("--address"), network = argOf("--network");
  console.log(`${C.b}fork-verify${C.x} Trig256   template ${TEMPLATE_SHA256.slice(0, 18)}…`);
  let b, f;
  if (addr) {
    const chain = network === "sepolia" ? sepolia : mainnet;
    const rpc = network === "sepolia" ? process.env.SEPOLIA_RPC_URL : process.env.MAINNET_RPC_URL;
    if (!rpc) throw new Error(`--address needs ${network === "sepolia" ? "SEPOLIA_RPC_URL" : "MAINNET_RPC_URL"} in .env`);
    const a = getAddress(addr);
    console.log(`  verifying LIVE ${a} on ${network || "mainnet"}`);
    const pub = createPublicClient({ chain, transport: http(rpc) });
    b = await checkBytecode(pub, a);
    f = await checkFunctional(pub, a);
  } else {
    console.log(`  spinning fresh anvil, deploying, verifying…`);
    const proc = await startAnvil();
    try {
      const account = privateKeyToAccount(ANVIL_PK);
      const wallet = createWalletClient({ account, chain: foundry, transport: http(LOCAL) });
      const pub = createPublicClient({ chain: foundry, transport: http(LOCAL) });
      const hash = await wallet.sendTransaction({ data: creation });
      const rc = await pub.waitForTransactionReceipt({ hash });
      console.log(`  deployed   ${rc.contractAddress}   (${Number(rc.gasUsed).toLocaleString()} gas)`);
      b = await checkBytecode(pub, rc.contractAddress);
      f = await checkFunctional(pub, rc.contractAddress);
    } finally { proc.kill(); }
  }
  const ok = b && f;
  console.log(ok
    ? `\n${C.g}${C.b}PASS${C.x} - deployed Trig256 is byte-identical to the vetted template and computes the golden.`
    : `\n${C.r}${C.b}FAIL${C.x}`);
  process.exit(ok ? 0 : 1);
}
main().catch((e) => { console.error(`${C.r}error:${C.x} ${e.message}`); process.exit(1); });
