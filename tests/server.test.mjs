// Simple routes and typed endpoints on the Hono adapter, called in-process through the app's fetch.
import { test } from "node:test";
import assert from "node:assert/strict";
import { app } from "./fixtures/src/TestApp.res.mjs";

const request = (path, init) => app.fetch(new Request(`http://localhost${path}`, init));
const post = (path, body) => request(path, { method: "POST", headers: { "content-type": "application/json" }, body });

const expectError = async (res, status, kind, path) => {
  assert.equal(res.status, status);
  const { error } = await res.json();
  assert.equal(error.kind, kind);
  if (path) assert.deepEqual(error.path, path);
  return error;
};

test("simple GET route returns JSON", async () => {
  const res = await request("/health");
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: "ok" });
});

test("simple route reads a path parameter", async () => {
  assert.equal(await (await request("/hello/Ada")).text(), "Hello, Ada!");
});

test("simple POST route reads the body", async () => {
  assert.equal(await (await request("/echo", { method: "POST", body: "ping" })).text(), "ping");
});

test("method mismatch and unknown routes are 404", async () => {
  assert.equal((await request("/echo")).status, 404);
  assert.equal((await request("/nope")).status, 404);
});

test("a ReScript exception in a route with no middleware is a logged plain 500", async t => {
  t.mock.method(console, "error", () => {});
  const res = await request("/throws");
  assert.equal(res.status, 500);
  assert.equal(await res.text(), "Internal Server Error");
  assert.equal(console.error.mock.callCount(), 1);
});

test("typed GET encodes the handler's response", async () => {
  const res = await request("/accounts/a1");
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { id: "a1", name: "Ann" });
});

test("typed endpoint receives percent-decoded params", async () => {
  assert.deepEqual(await (await request("/accounts/a%2Fb%20c")).json(), { id: "a/b c", name: "Slashed" });
});

test("a declared application error is sent with its status and encoded value", async () => {
  const notFound = await request("/accounts/missing");
  assert.equal(notFound.status, 404);
  assert.deepEqual(await notFound.json(), { applicationError: "not_found" });
  const denied = await request("/accounts/secret");
  assert.equal(denied.status, 403);
  assert.deepEqual(await denied.json(), { applicationError: "access_denied" });
});

test("an application error mapped to a non-error status is an internal error", async t => {
  t.mock.method(console, "error", () => {});
  await expectError(await request("/bad-error-status"), 500, "internal");
  const logged = console.error.mock.calls[0].arguments[0];
  assert.ok(logged instanceof Error, "logs the JS Error itself, with its stack");
  assert.match(logged.message, /must be 4xx or 5xx, got 200/);
});

test("typed POST decodes params and body", async () => {
  const res = await post("/orgs/acme/members/42", JSON.stringify({ name: "Ann" }));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { id: "acme/42", name: "Ann" });
});

test("invalid params are rejected with their path", async () => {
  await expectError(await post("/orgs/acme/members/abc", JSON.stringify({ name: "Ann" })), 400, "invalid_params", ["member"]);
});

test("invalid params are rejected before the body is read", async () => {
  let pulled = false;
  // highWaterMark 0: pull runs only when something reads, not eagerly to fill the queue.
  const body = new ReadableStream({ pull() { pulled = true; throw new Error("body must not be read"); } }, { highWaterMark: 0 });
  const res = await request("/orgs/acme/members/abc", { method: "POST", body, duplex: "half" });
  await expectError(res, 400, "invalid_params", ["member"]);
  assert.equal(pulled, false);
});

test("a body that fails to read is a 500 internal, not malformed_json", async t => {
  t.mock.method(console, "error", () => {});
  const body = new ReadableStream({ pull() { throw new Error("secret stream failure"); } }, { highWaterMark: 0 });
  const res = await request("/accounts", { method: "POST", body, duplex: "half" });
  const error = await expectError(res, 500, "internal");
  assert.doesNotMatch(JSON.stringify(error), /secret stream failure/);
  assert.equal(console.error.mock.callCount(), 1);
});

test("malformed JSON and an empty body are malformed_json", async () => {
  await expectError(await post("/accounts", "{not json"), 400, "malformed_json");
  await expectError(await post("/accounts", ""), 400, "malformed_json");
});

test("a body that fails the codec is invalid_body with its path", async () => {
  await expectError(await post("/accounts", JSON.stringify({ name: 1 })), 400, "invalid_body", ["name"]);
});

test("an encoder exception is a 500 that hides the exception", async t => {
  t.mock.method(console, "error", () => {});
  const res = await request("/broken");
  const error = await expectError(res, 500, "internal");
  assert.equal(error.message, "Internal Server Error");
  assert.equal(console.error.mock.callCount(), 1);
  assert.doesNotMatch(JSON.stringify(error), /secret internal detail/);
});

for (const [name, path, init] of [
  ["a body decoder exception", "/throwing-body", { method: "POST", body: JSON.stringify({ name: "Ann" }) }],
  ["an application-error encoder exception", "/throwing-error-codec"],
  ["a handler rejecting with a ReScript exception", "/orgs/acme/members/42"],
]) {
  test(`${name} is a logged 500 that hides the exception`, async t => {
    t.mock.method(console, "error", () => {});
    const error = await expectError(await request(path, init), 500, "internal");
    assert.equal(error.message, "Internal Server Error");
    assert.doesNotMatch(JSON.stringify(error), /secret internal detail|Not_found/);
    assert.equal(console.error.mock.callCount(), 1);
  });
}
