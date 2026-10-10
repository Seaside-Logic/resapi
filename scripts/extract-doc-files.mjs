// Writes each whole-file ReScript block of a Markdown doc into a project's src/, so the doc's examples
// can be compiled. A whole-file block is a ```rescript block whose first line is `// Name.res` or
// `// src/Dir/Name.res`. Other blocks are excerpts and are skipped.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const [doc, dest] = process.argv.slice(2);
const blocks = [...readFileSync(doc, "utf8").matchAll(/^```rescript\n\/\/ (?:src\/)?([\w/]+\.res)\n([\s\S]*?)^```$/gm)];
if (!blocks.length) throw new Error(`${doc} has no whole-file rescript blocks`);
for (const [, path, body] of blocks) {
  const file = join(dest, "src", path);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, body);
  console.log(`${doc}: ${path}`);
}
