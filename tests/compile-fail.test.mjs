// Each case in compile-fail/cases must fail to compile with the message in its `// expect:` line
// (or compile, for "compiles"). Cases are copied one at a time into src/Case.res, next to the shared CaseApi.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";

const dir = new URL("./compile-fail/", import.meta.url).pathname;
const caseFile = join(dir, "src/Case.res");
const rescript = new URL("../node_modules/.bin/rescript", import.meta.url).pathname;

const compile = () => {
  try {
    execFileSync(rescript, ["build"], { cwd: dir, stdio: "pipe" });
    return { ok: true, output: "" };
  } catch (e) {
    return { ok: false, output: (e.stdout + e.stderr).replace(/\x1b\[[0-9;]*m/g, "") };
  }
};

for (const name of readdirSync(join(dir, "cases")).sort()) {
  test(`compile-fail: ${name}`, () => {
    const source = readFileSync(join(dir, "cases", name), "utf8");
    const expected = source.match(/^\/\/ expect: (.*)$/m)[1];
    // Blank the expect line (keeping line numbers): the compiler's source excerpt would otherwise contain it
    // and every expectation would match itself.
    writeFileSync(caseFile, source.replace(/^\/\/ expect: .*$/m, "//"));
    try {
      const { ok, output } = compile();
      if (expected === "compiles") return assert.ok(ok, output);
      assert.ok(!ok, "expected a compile error, but it compiled");
      assert.ok(output.includes(expected), `missing "${expected}" in:\n${output}`);
    } finally {
      rmSync(caseFile, { force: true });
      rmSync(caseFile.replace(/\.res$/, ".res.mjs"), { force: true });
    }
  });
}
