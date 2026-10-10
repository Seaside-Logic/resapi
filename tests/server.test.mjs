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
  const error = await expectError(await request("/accounts/a%2Fb%20c"), 404, "application");
  assert.equal(error.message, "No account a/b c");
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
