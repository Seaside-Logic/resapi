// Native Hono middleware through Router.use, including Hono's own built-in middleware.
import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import * as Fixture from "./fixtures/src/MiddlewareApp.res.mjs";

const call = (path, init) => Fixture.app.fetch(new Request(`http://localhost${path}`, init));

beforeEach(() => {
  Fixture.events.length = 0;
  Fixture.logLines.length = 0;
});

test("middleware runs in registration order, outermost first", async () => {
  await call("/ok");
  assert.deepEqual(Fixture.events, ["outer:before", "inner:before", "handler", "inner:after", "outer:after"]);
});

test("middleware can set a header after next(), on routes and on 404s", async () => {
  assert.equal((await call("/ok")).headers.get("x-powered-by"), "resAPI");
  assert.equal((await call("/missing")).headers.get("x-powered-by"), "resAPI");
});

test("returning Some(response) answers early and skips the handler", async () => {
  const res = await call("/denied");
  assert.equal(res.status, 403);
  assert.equal(await res.text(), "denied");
  assert.ok(!Fixture.events.includes("handler"));
});

test("middleware wraps typed endpoints: it can reject, and it sees and changes their responses", async () => {
  assert.equal((await call("/accounts/a1")).status, 401);
  assert.ok(!Fixture.events.includes("handler"));
  Fixture.events.length = 0;
  const res = await call("/accounts/a1", { headers: { authorization: "Bearer secret" } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("x-powered-by"), "resAPI");
  assert.deepEqual(await res.json(), { id: "a1", name: "Ann" });
  assert.deepEqual(Fixture.events, ["outer:before", "inner:before", "handler", "inner:after", "outer:after"]);
});

test("Hono's logger middleware works through a one-line binding", async () => {
  await call("/ok");
  assert.equal(Fixture.logLines.length, 2);
  assert.match(Fixture.logLines[1], /GET \/ok .*200/);
});

test("Hono's bearerAuth middleware works, including its HTTPException responses", async () => {
  assert.equal((await call("/protected")).status, 401);
  assert.equal((await call("/protected", { headers: { authorization: "Bearer wrong" } })).status, 401);
  const res = await call("/protected", { headers: { authorization: "Bearer secret" } });
  assert.equal(res.status, 200);
  assert.equal(await res.text(), "secret");
});

for (const path of ["/uncaught-rescript", "/uncaught-js", "/uncaught-typed", "/middleware-throws"]) {
  test(`an uncaught exception is a logged plain 500 (${path})`, async t => {
    t.mock.method(console, "error", () => {});
    const res = await call(path);
    assert.equal(res.status, 500);
    assert.equal(await res.text(), "Internal Server Error");
    assert.equal(console.error.mock.callCount(), 1);
  });
}

test("a handler's exception becomes a 500 response that outer middleware sees", async t => {
  t.mock.method(console, "error", () => {});
  await call("/uncaught-rescript");
  assert.deepEqual(Fixture.events, ["outer:before", "inner:before", "inner:after", "outer:after"]);
});
