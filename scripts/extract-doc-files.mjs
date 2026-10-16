// Writes each whole-file ReScript block of a Markdown doc into a project's src/, so the doc's examples
// can be compiled. A whole-file block is a ```rescript block whose first line is `// Name.res` or
// `// src/Dir/Name.res`. Other blocks are excerpts and are skipped.
//
// An optional framework (hono or express) keeps that framework's `<div data-framework="...">` sections
// and drops the others', so a doc with both versions of a file yields one project per framework.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const [doc, dest, framework] = process.argv.slice(2);
let source = readFileSync(doc, "utf8");
if (framework)
  source = source.replace(/^<div data-framework="(\w+)">\n[\s\S]*?^<\/div>$/gm, (section, name) =>
    name === framework ? section : "",
  );
const blocks = [...source.matchAll(/^```rescript\n\/\/ (?:src\/)?([\w/]+\.res)\n([\s\S]*?)^```$/gm)];
if (!blocks.length) throw new Error(`${doc} has no whole-file rescript blocks`);
const paths = blocks.map(([, path]) => path);
const repeated = paths.find((path, i) => paths.indexOf(path) !== i);
if (repeated) throw new Error(`${doc} defines ${repeated} more than once${framework ? "" : "; pass a framework"}`);
for (const [, path, body] of blocks) {
  const file = join(dest, "src", path);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, body);
  console.log(`${doc}: ${path}`);
}
