// Auth as middleware: typed request keys (Task 1) and Reject (Task 2), on Hono and Express.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import http from "node:http";
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

test("hono: a key reads a value set with Hono's own c.set; unset or null is None", async () => {
  assert.equal(await (await hono(AuthApp.app, "/tenant")).text(), "acme");
  assert.equal(await (await hono(AuthApp.app, "/no-tenant")).text(), "none");
  assert.equal(await (await hono(AuthApp.app, "/null-tenant")).text(), "none");
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

const rejection = (kind, message = "") => ({ error: { kind, message, path: [] } });

test("hono: Reject answers 401 and 403 in resAPI's error shape, with an optional reason", async () => {
  const anonymous = await hono(AuthApp.app, "/accounts/a1");
  assert.equal(anonymous.status, 401);
  assert.deepEqual(await anonymous.json(), rejection("unauthenticated"));
  const banned = await hono(AuthApp.app, "/accounts/a1", as("mallory"));
  assert.equal(banned.status, 403);
  assert.deepEqual(await banned.json(), rejection("forbidden", "banned"));
  const noReason = await hono(AuthApp.app, "/accounts/a1", as("eve"));
  assert.deepEqual(await noReason.json(), rejection("forbidden"));
});

test("express: Reject answers 401 and 403 in resAPI's error shape", async () => {
  const anonymous = await fetch(`${expressBase}/accounts/a1`);
  assert.equal(anonymous.status, 401);
  assert.deepEqual(await anonymous.json(), rejection("unauthenticated"));
  const banned = await fetch(`${expressBase}/accounts/a1`, as("mallory"));
  assert.equal(banned.status, 403);
  assert.deepEqual(await banned.json(), rejection("forbidden", "banned"));
  const noReason = await fetch(`${expressBase}/accounts/a1`, as("eve"));
  assert.equal(noReason.status, 403);
  assert.deepEqual(await noReason.json(), rejection("forbidden"));
});

test("hono: a rejected POST is answered without reading its body", async () => {
  let pulled = false;
  // A body that never ends: reading it would hang the request.
  const body = new ReadableStream({ pull() { pulled = true; } }, { highWaterMark: 0 });
  const res = await hono(AuthApp.app, "/accounts", { method: "POST", body, duplex: "half" });
  assert.equal(res.status, 401);
  assert.deepEqual(await res.json(), rejection("unauthenticated"));
  assert.equal(pulled, false);
});

test("hono: an authenticated POST reaches the typed handler with the user", async () => {
  const res = await hono(AuthApp.app, "/accounts", { method: "POST", body: JSON.stringify({ name: "Acct" }), headers: { "x-user": "ann" } });
  assert.deepEqual(await res.json(), { id: "new", name: "Acct by ann" });
});

test("express: a rejected request is answered before its body is read", async () => {
  const { port } = new URL(expressBase);
  const req = http.request({ port, path: "/accounts", method: "POST", headers: { "content-type": "application/json", "content-length": "1000000" } });
  const response = new Promise((resolve, reject) => { req.on("response", resolve); req.on("error", reject); });
  req.write('{"name":'); // the rest never arrives
  const res = await response;
  assert.equal(res.statusCode, 401);
  res.resume();
  req.destroy();
});
