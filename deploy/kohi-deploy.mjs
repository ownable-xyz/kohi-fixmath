#!/usr/bin/env node
// SPDX-License-Identifier: MIT
//
// kohi-deploy.mjs: this script deploys Trig256, the only deployable contract
// in kohi-fixmath.
//
// The default is a dry run. The script broadcasts only with --send (or
// SEND=1). For mainnet, you must also type "mainnet". The script does these
// checks:
//   - Before the deployment, it checks eth_chainId and web3_clientVersion.
//     Thus, it refuses --network mainnet when the node is an anvil fork.
//   - The deployment applies the EIP-7825 gas cap to itself.
//   - After the deployment, it reads the code again and masks the address
//     guard of the library. It records the deployment only if the hash agrees
//     with the approved template.
//
// Signing (select one):
//   --ledger (or LEDGER=1)  Sign on a Ledger through `forge create`. Set SENDER
//                           to your Ledger address at HD_PATH. The key stays on
//                           the device. A PRIVATE_KEY that you set together
//                           with --ledger is a test override for a rehearsal on
//                           a fork: forge signs with --private-key.
//   PRIVATE_KEY             A hot key through viem (for tests and testnets).
//   SENDER + Frame          A Frame hardware wallet through viem.
//   --network anvil         The default is the standard anvil dev key.
//
//   node deploy/kohi-deploy.mjs status   --network mainnet
//   node deploy/kohi-deploy.mjs deploy   --network mainnet --ledger        # dry run
//   SEND=1 node deploy/kohi-deploy.mjs deploy --network mainnet --ledger   # broadcasts
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline/promises";
import { createPublicClient, createWalletClient, http, getAddress, formatEther, formatGwei } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry, mainnet, sepolia } from "viem/chains";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const C = { g: "\x1b[32m", r: "\x1b[31m", y: "\x1b[33m", b: "\x1b[1m", d: "\x1b[2m", x: "\x1b[0m" };
const TEMPLATE_SHA256 = "9e4d0e8e8712c70230085669c170a45ff58f243b3ded1b0bf4fc9a0f3ec9645d";
const GAS_CAP = Math.floor(16_777_216 * 0.95);
const ANVIL_PK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

(() => {
  const f = join(ROOT, ".env");
  if (!existsSync(f)) return;
  for (const line of readFileSync(f, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!m || m[1] in process.env) continue;
    process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
})();

const die = (msg) => { console.error(`${C.r}error:${C.x} ${msg}`); process.exit(1); };
const argOf = (name, def) => { const i = process.argv.indexOf(name); return i > -1 ? process.argv[i + 1] : def; };
const flag = (name) => process.argv.includes(name);

const CMD = process.argv[2];
const NETWORK = argOf("--network", process.env.NETWORK || "anvil");
const SEND = flag("--send") || process.env.SEND === "1";
const FORCE = flag("--force");
const USE_LEDGER = flag("--ledger") || process.env.LEDGER === "1";
const HD_PATH = process.env.HD_PATH ?? "m/44'/60'/0'/0/0";
const CAST_KEY = process.env.PRIVATE_KEY || argOf("--private-key") || null;
const LOCAL = "http://127.0.0.1:8545";

const art = JSON.parse(readFileSync(join(ROOT, "out/Trig256.sol/Trig256.json"), "utf8"));
const creation = art.bytecode.object;
const INIT_BYTES = (creation.length - 2) / 2;

const sha256 = (s) => createHash("sha256").update(s).digest("hex");
function maskGuard(code) {
  if (!code || code.slice(0, 4).toLowerCase() !== "0x73") return code;
  return code.slice(0, 4) + "0".repeat(40) + code.slice(44);
}

function chainFor() { return NETWORK === "mainnet" ? mainnet : NETWORK === "sepolia" ? sepolia : foundry; }
function rpcFor() {
  const r = argOf("--rpc");
  if (r) return r;
  if (NETWORK === "mainnet") return process.env.MAINNET_RPC_URL || die("set MAINNET_RPC_URL");
  if (NETWORK === "sepolia") return process.env.SEPOLIA_RPC_URL || die("set SEPOLIA_RPC_URL");
  return process.env.RPC_URL || LOCAL;
}
const ledgerPath = () => join(ROOT, "deploy", "deployments", `${NETWORK}.json`);
function loadLedger() { const p = ledgerPath(); return existsSync(p) ? JSON.parse(readFileSync(p, "utf8")) : { network: NETWORK }; }
function saveLedger(l) { mkdirSync(dirname(ledgerPath()), { recursive: true }); writeFileSync(ledgerPath(), JSON.stringify(l, null, 2) + "\n"); }

const pubClient = () => createPublicClient({ chain: chainFor(), transport: http(rpcFor()) });

// Find the signer. The kind "ledger" broadcasts through `forge create` (on the
// device). The kind "viem" broadcasts through a wallet client (hot key, Frame
// or anvil dev key).
function signer() {
  if (USE_LEDGER) {
    const s = CAST_KEY ? privateKeyToAccount(CAST_KEY).address : (process.env.SENDER || die("--ledger needs SENDER = your Ledger address at HD_PATH"));
    return { sender: getAddress(s), kind: "ledger", mode: `Ledger via forge create, path ${HD_PATH}${CAST_KEY ? " (TEST: --private-key override)" : ""}` };
  }
  const pk = CAST_KEY || (NETWORK === "anvil" ? ANVIL_PK : null);
  if (pk) {
    const account = privateKeyToAccount(pk);
    return { sender: account.address, kind: "viem", mode: NETWORK === "anvil" && !CAST_KEY ? "anvil dev key" : "hot key (PRIVATE_KEY)", wallet: createWalletClient({ account, chain: chainFor(), transport: http(rpcFor()) }) };
  }
  const frame = process.env.FRAME_RPC || "http://127.0.0.1:1248";
  const s = getAddress(process.env.SENDER || die("set PRIVATE_KEY, SENDER (for Frame), or use --ledger"));
  return { sender: s, kind: "viem", mode: `Frame (hardware) @ ${frame}`, wallet: createWalletClient({ account: s, chain: chainFor(), transport: http(frame) }) };
}

// forge builds the initcode internally, so the command line contains no
// bytecode. Thus, the Windows limit of approximately 32 KB for arguments does
// not apply. Returns { hash, address }.
function forgeCreate({ contractId, libraries = [] }) {
  const args = ["create", contractId, "--rpc-url", rpcFor(), "--broadcast", "--json"];
  for (const lib of libraries) args.push("--libraries", lib);
  if (CAST_KEY) args.push("--private-key", CAST_KEY);
  else args.push("--ledger", "--mnemonic-derivation-path", HD_PATH);
  if (!CAST_KEY) console.log(`  ${C.y}forge builds + estimates, then your Ledger will prompt to sign. Live output:${C.x}`);
  let out;
  try { out = execFileSync("forge", args, { stdio: ["inherit", "pipe", "inherit"], maxBuffer: 1 << 26, cwd: ROOT }).toString(); }
  catch (e) { die(`forge create failed (see output above). exit ${e.status ?? "?"}`); }
  const m = out.match(/\{[\s\S]*\}/);
  if (!m) die(`forge create: no JSON receipt in output:\n${out.slice(-400)}`);
  const r = JSON.parse(m[0]);
  if (!r.deployedTo) die(`forge create: no deployedTo in receipt:\n${m[0].slice(0, 300)}`);
  return { hash: r.transactionHash, address: getAddress(r.deployedTo) };
}

async function preflight(pub) {
  const cid = await pub.getChainId();
  const expect = NETWORK === "mainnet" ? 1 : NETWORK === "sepolia" ? 11155111 : 31337;
  if (cid !== expect) die(`chain id ${cid} != ${expect} expected for --network ${NETWORK}`);
  let client = "";
  try { client = await pub.request({ method: "web3_clientVersion" }); } catch { client = "(unknown)"; }
  const isDev = /anvil|hardhat|foundry|ganache/i.test(client);
  if (NETWORK === "mainnet" && isDev) die(`--network mainnet but the node reports "${client}" (a dev/fork node). Refusing.`);
  if (NETWORK === "anvil" && !isDev) die(`--network anvil but the node reports "${client}" (not a dev node).`);
  console.log(`  preflight  chain ${cid}   node ${C.d}${client}${C.x}`);
}

async function ask(q) { const rl = createInterface({ input: process.stdin, output: process.stdout }); const a = await rl.question(q); rl.close(); return a.trim(); }

async function cmdStatus() {
  const pub = pubClient();
  console.log(`${C.b}status${C.x}  network ${NETWORK}   signer ${signer().mode}`);
  await preflight(pub).catch((e) => console.log(`  ${C.y}${e.message}${C.x}`));
  const led = loadLedger();
  const rec = led.Trig256;
  if (!rec?.address) { console.log(`  Trig256    ${C.y}not in ledger${C.x}   (${INIT_BYTES} B init, template ${TEMPLATE_SHA256.slice(0, 18)}…)`); return; }
  const code = await pub.getCode({ address: rec.address }).catch(() => null);
  const live = code && code !== "0x";
  const matches = live && sha256(maskGuard(code)) === TEMPLATE_SHA256;
  console.log(`  Trig256    ${rec.address}   ${live ? (matches ? C.g + "live, byte-identical" + C.x : C.r + "live, DRIFT" + C.x) : C.r + "no code on chain" + C.x}`);
  console.log(`             tx ${rec.txHash}  block ${rec.block}  verified ${rec.sourceVerified ? "yes" : C.y + "no (deferred)" + C.x}`);
}

async function cmdEstimate() {
  const pub = pubClient();
  await preflight(pub);
  const { sender } = signer();
  const gas = await pub.estimateGas({ account: sender, data: creation });
  const fee = await pub.getGasPrice();
  console.log(`  estimate   deploy Trig256 (${INIT_BYTES} B init) from ${sender}`);
  console.log(`             gas ${Number(gas).toLocaleString()}  ${Number(gas) > GAS_CAP ? C.r + "OVER EIP-7825 cap" + C.x : C.g + "under cap" + C.x} (${GAS_CAP.toLocaleString()})`);
  console.log(`             gasPrice ${formatGwei(fee)} gwei   ~${formatEther(gas * fee)} ETH at current fee`);
}

async function cmdDeploy() {
  const pub = pubClient();
  await preflight(pub);
  const { sender, mode, kind, wallet } = signer();

  const led = loadLedger();
  if (led.Trig256?.address && !FORCE) {
    const code = await pub.getCode({ address: led.Trig256.address }).catch(() => null);
    if (code && code !== "0x") die(`Trig256 already deployed at ${led.Trig256.address} on ${NETWORK}. Pass --force to redeploy (the old one stays on-chain).`);
  }

  const gas = await pub.estimateGas({ account: sender, data: creation });
  if (Number(gas) > GAS_CAP) die(`deploy estimates ${Number(gas).toLocaleString()} gas, over the ${GAS_CAP.toLocaleString()} EIP-7825 cap.`);
  const fee = await pub.getGasPrice();

  console.log(`\n${C.b}deploy plan${C.x}`);
  console.log(`  contract   Trig256 (MIT)   ${INIT_BYTES} B init`);
  console.log(`  to         ${NETWORK}   from ${sender}   via ${mode}`);
  console.log(`  gas        ${Number(gas).toLocaleString()}   ~${formatEther(gas * fee)} ETH at ${formatGwei(fee)} gwei`);
  console.log(`  expect     runtime hashes to ${TEMPLATE_SHA256.slice(0, 18)}… after deploy`);

  if (!SEND) { console.log(`\n  ${C.y}DRY-RUN${C.x} - pass --send (or SEND=1) to broadcast.`); return; }
  if (NETWORK === "mainnet") {
    const typed = await ask(`\n  ${C.r}${C.b}MAINNET BROADCAST.${C.x} Type "mainnet" to proceed: `);
    if (typed !== "mainnet") die("aborted (did not type mainnet).");
  }

  console.log(`\n  broadcasting…`);
  let address, hash;
  if (kind === "ledger") ({ address, hash } = forgeCreate({ contractId: "src/Trig256.sol:Trig256" }));
  else hash = await wallet.sendTransaction({ data: creation });
  console.log(`  tx         ${hash}`);
  const rc = await pub.waitForTransactionReceipt({ hash });
  if (rc.status !== "success") die(`deploy tx reverted (${hash}).`);
  if (!address) address = getAddress(rc.contractAddress);

  const code = await pub.getCode({ address });
  const got = sha256(maskGuard(code));
  if (got !== TEMPLATE_SHA256) die(`deployed runtime hashes to ${got}, NOT the vetted template ${TEMPLATE_SHA256}. Refusing to record.`);
  console.log(`  ${C.g}verified${C.x}   on-chain runtime byte-identical to template   ${address}   block ${rc.blockNumber}`);

  led.Trig256 = { address, txHash: hash, block: Number(rc.blockNumber), deployer: sender, templateSha256: TEMPLATE_SHA256, sourceVerified: false, at: new Date().toISOString() };
  saveLedger(led);
  console.log(`  ledger     ${ledgerPath().replace(ROOT, ".")}`);
  printVerifyRecipe(address);
}

function printVerifyRecipe(address) {
  console.log(`\n  ${C.b}source verification${C.x} (deferred, manual, one-way - publishes the full MIT source tree):`);
  console.log(`    forge verify-contract ${address} src/Trig256.sol:Trig256 \\`);
  console.log(`      --chain ${NETWORK} --compiler-version v0.8.24 --optimizer-runs 200 --watch`);
  console.log(`    ${C.d}needs ETHERSCAN_API_KEY. Trig256/Fix64/SinLut256/Errors are all MIT.${C.x}`);
}

const CMDS = { status: cmdStatus, estimate: cmdEstimate, deploy: cmdDeploy, "verify-note": () => printVerifyRecipe(loadLedger().Trig256?.address || "<address>") };
const run = CMDS[CMD];
if (!run) { console.error(`usage: node deploy/kohi-deploy.mjs <status|estimate|deploy|verify-note> [--network mainnet|sepolia|anvil] [--ledger] [--send] [--force]`); process.exit(1); }
run().catch((e) => die(e.shortMessage || e.message));
