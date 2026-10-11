// Auth as middleware: typed request keys (Task 1) and Reject (Task 2), on Hono and Express.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import * as AuthApp from "./fixtures/src/AuthApp.res.mjs";
import * as ExpressAuthApp from "./fixtures/src/ExpressAuthApp.res.mjs";

const hono = (app, path, init) => app.fetch(new Request(`http://localhost${path}`, init));
const as = user => (user ? { headers: { "x-user": user } } : {});

const serve = async app => {
  const server = app.listen(0);
  await once(server, "listening");
  after(() => server.close());
  return `http://localhost:${server.address().port}`;
};
const expressBase = await serve(ExpressAuthApp.app);

test("hono: middleware stores the user under a key, and the typed handler reads it", async () => {
  const res = await hono(AuthApp.app, "/accounts/a1", as("ann"));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { id: "a1", name: "ann" });
});

test("hono: a key reads a value set with Hono's own c.set; unset is None", async () => {
  assert.equal(await (await hono(AuthApp.app, "/tenant")).text(), "acme");
  assert.equal(await (await hono(AuthApp.app, "/no-tenant")).text(), "none");
});

test("hono: middleware registered after the route doesn't run for it; getOrThrow makes that an opaque 500", async t => {
  t.mock.method(console, "error", () => {});
  const res = await hono(AuthApp.lateApp, "/accounts/a1");
  assert.equal(res.status, 500);
  const body = await res.text();
  assert.match(body, /"kind":"internal"/);
  assert.doesNotMatch(body, /No value for key/);
  assert.match(console.error.mock.calls[0].arguments[0].message, /No value for key "user": is its middleware mounted for this path\?/);
});

test("express: middleware stores the user on req under a key, and the typed handler reads it", async () => {
  const res = await fetch(`${expressBase}/accounts/a1`, as("ann"));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { id: "a1", name: "ann" });
});

test("express: a key reads a Passport-style req.user, and null is None", async () => {
  assert.equal(await (await fetch(`${expressBase}/passport`, { headers: { "x-passport": "bo" } })).text(), "bo");
  assert.equal(await (await fetch(`${expressBase}/passport`)).text(), "nobody");
});
