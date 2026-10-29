// Fails if CHANGELOG.md has no "## <version>" heading for the version in packages/core/package.json.
// The release workflow checks that every package matches the tag, so core's version stands for all four.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const root = resolve(dirname(new URL(import.meta.url).pathname), "..");
const { version } = JSON.parse(
  readFileSync(join(root, "packages/core/package.json"), "utf8"),
);
const changelog = readFileSync(join(root, "CHANGELOG.md"), "utf8");
const escaped = version.replace(/\./g, "\\.");

if (!new RegExp(`^## ${escaped}(\\s|$)`, "m").test(changelog)) {
  console.error(`CHANGELOG.md has no "## ${version}" entry.`);
  process.exit(1);
}
