// Package-boundary check on the compiled output. ReScript emits an external's import where the external
// is called, not where it is declared, so a package's own files say little: this walks the real import
// graph from entry points, following relative and @resapi/* imports, and records every other package
// reached. Run after a build.
import { readFileSync, readdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";

const root = resolve(dirname(new URL(import.meta.url).pathname), "..");
const importPattern = /^\s*(?:import|export)\b[^;]*?\bfrom\s*"([^"]+)"|^\s*import\s*"([^"]+)"/gm;

// Every external package reachable from `entry`, e.g. "hono", "hono/logger", "sury".
const externalsReachable = entry => {
  const seen = new Set();
  const externals = new Set();
  const visit = file => {
    if (seen.has(file)) return;
    seen.add(file);
    for (const match of readFileSync(file, "utf8").matchAll(importPattern)) {
      const spec = match[1] ?? match[2];
      if (spec.startsWith(".")) visit(resolve(dirname(file), spec));
      else if (spec.startsWith("@resapi/")) visit(createRequire(file).resolve(spec));
      else if (!spec.startsWith("@rescript/runtime")) externals.add(spec);
    }
  };
  visit(resolve(root, entry));
  return externals;
};

const sources = dir => readdirSync(join(root, dir)).filter(f => f.endsWith(".res.mjs")).map(f => join(dir, f));
const isPackage = (spec, name) => spec === name || spec.startsWith(`${name}/`);

const rules = [
  { entries: ["examples/cloudflare/src/AccountClient.res.mjs"], forbidden: ["hono", "@resapi/hono", "cloudflare:"] },
  { entries: ["examples/express/src/AccountClient.res.mjs"], forbidden: ["express", "@resapi/express", "node:"] },
  {
    entries: sources("packages/core/src"),
    forbidden: ["hono", "express", "sury", "@resapi/hono", "@resapi/express", "@resapi/sury", "node:", "cloudflare:"],
  },
  { entries: sources("packages/sury/src"), forbidden: ["hono", "express", "@resapi/hono", "@resapi/express"] },
  { entries: sources("packages/hono/src"), forbidden: ["sury", "express", "@resapi/sury", "@resapi/express"] },
  { entries: sources("packages/express/src"), forbidden: ["sury", "hono", "@resapi/sury", "@resapi/hono"] },
];

let failed = false;
for (const { entries, forbidden } of rules) {
  for (const entry of entries) {
    const bad = [...externalsReachable(entry)].filter(spec => forbidden.some(name => isPackage(spec, name) || spec.startsWith(name)));
    if (bad.length) {
      failed = true;
      console.error(`FAIL ${entry} reaches ${bad.join(", ")}`);
    } else {
      console.log(`ok   ${entry}`);
    }
  }
}

// Positive controls: each server entry must reach its framework, or the walk is broken and every check
// above is vacuous.
for (const [entry, framework] of [
  ["examples/cloudflare/src/Worker.res.mjs", "hono"],
  ["examples/express/src/Server.res.mjs", "express"],
]) {
  const server = externalsReachable(entry);
  if (![...server].some(spec => isPackage(spec, framework))) {
    failed = true;
    console.error(`FAIL control: ${entry} should reach ${framework} but the walk found none`);
  } else {
    console.log(`ok   control: ${entry} reaches ${[...server].sort().join(", ")}`);
  }
}

process.exit(failed ? 1 : 0);
