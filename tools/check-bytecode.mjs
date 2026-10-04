// SPDX-License-Identifier: MIT
// Bytecode check: the deployed bytecode must reproduce the recorded hashes.
// An accidental edit of a source, or a change of the foundry.toml settings,
// changes the hash and makes the build fail. Refer to docs/bytecode-identity.md.
import { execSync } from "node:child_process";
import { createHash } from "node:crypto";

const EXPECT = {
  "src/Trig256.sol:Trig256": "9e4d0e8e8712c70230085669c170a45ff58f243b3ded1b0bf4fc9a0f3ec9645d",
};

let failed = false;
for (const [id, want] of Object.entries(EXPECT)) {
  const hex = execSync(`forge inspect ${id} deployedBytecode`).toString().trim();
  const got = createHash("sha256").update(hex).digest("hex");
  const ok = got === want;
  if (!ok) failed = true;
  console.log(`${ok ? "OK   " : "DRIFT"} ${id}  ${got}`);
}
process.exit(failed ? 1 : 0);
