// The Express adapter and the Express example, over HTTP on an ephemeral port. Dispatch's pipeline is
// shared with Hono and covered in server.test.mjs and typed-errors.test.mjs; this covers what Express adds.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import * as Client from "../packages/core/src/Client.res.mjs";
import { app, jsonApp } from "./fixtures/src/ExpressTestApp.res.mjs";
import * as AccountClient from "../examples/express/src/AccountClient.res.mjs";
import { app as exampleApp } from "../examples/express/src/App.res.mjs";

const secret = "test-secret";
process.env.API_SECRET = secret;

const serve = async app => {
  const server = app.listen(0);
  await once(server, "listening");
  after(() => server.close());
  return `http://localhost:${server.address().port}`;
};

const [base, jsonBase, exampleBase] = await Promise.all([serve(app), serve(jsonApp), serve(exampleApp)]);
const request = (path, init) => fetch(`${base}${path}`, init);
const post = (path, body) => request(path, { method: "POST", body });

const expectError = async (res, status, kind, path) => {
  assert.equal(res.status, status);
  const { error } = await res.json();
  assert.equal(error.kind, kind);
  if (path) assert.deepEqual(error.path, path);
  return error;
};

test("express: simple route reads a path parameter", async () => {
  assert.equal(await (await request("/hello/Ada")).text(), "Hello, Ada!");
});

test("express: unknown routes and method mismatches are 404", async () => {
  assert.equal((await request("/nope")).status, 404);
  assert.equal((await post("/hello/Ada", "")).status, 404);
});

test("express: a ReScript exception in a simple route is a 500 from Express's error handler", async t => {
  t.mock.method(console, "error", () => {});
  assert.equal((await request("/throws")).status, 500);
  const logged = console.error.mock.calls[0].arguments[0];
  assert.match(logged, /^Error: Uncaught ReScript exception: .*Not_found/);
});

test("express: typed GET receives percent-decoded params", async () => {
  assert.deepEqual(await (await request("/accounts/a%2Fb%20c")).json(), { id: "a/b c", name: "Slashed" });
});

test("express: a declared application error is sent with its status and encoded value", async () => {
  const denied = await request("/accounts/secret");
  assert.equal(denied.status, 403);
  assert.deepEqual(await denied.json(), { applicationError: "access_denied" });
});

test("express: typed POST decodes params and body, whatever the content type", async () => {
  const res = await post("/orgs/acme/members/42", JSON.stringify({ name: "Ann" }));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { id: "acme/42", name: "Ann" });
  await expectError(await post("/orgs/acme/members/abc", "{}"), 400, "invalid_params", ["member"]);
});

test("express: malformed JSON, an empty body and a bad body are 400s", async () => {
  await expectError(await post("/accounts", "{not json"), 400, "malformed_json");
  await expectError(await request("/accounts", { method: "POST" }), 400, "malformed_json");
  await expectError(await post("/accounts", JSON.stringify({ name: 1 })), 400, "invalid_body", ["name"]);
});

test("express: an encoder exception is a 500 that hides the exception", async t => {
  t.mock.method(console, "error", () => {});
  const error = await expectError(await request("/broken"), 500, "internal");
  assert.doesNotMatch(JSON.stringify(error), /secret internal detail/);
  assert.equal(console.error.mock.callCount(), 1);
});

test("express: a body already parsed by express.json() is used as is", async () => {
  const init = { method: "POST", headers: { "content-type": "application/json" } };
  const res = await fetch(`${jsonBase}/accounts`, { ...init, body: JSON.stringify({ name: "Bo" }) });
  assert.deepEqual(await res.json(), { id: "new", name: "Bo" });
  const bad = await fetch(`${jsonBase}/accounts`, { ...init, body: JSON.stringify({ name: 1 }) });
  await expectError(bad, 400, "invalid_body", ["name"]);
});

// The example, through its own client.
const client = Client.make(exampleBase);
const exampleRequest = (path, init) => fetch(`${exampleBase}${path}`, init);

test("express example: typed GET, typed error and typed POST through the client", async () => {
  assert.deepEqual(await AccountClient.getAccount(client, "acct_123"), {
    TAG: "Ok",
    _0: { id: "acct_123", name: "Retirement Savings", balance: 250000, nickname: undefined },
  });
  assert.equal(await AccountClient.describe(client, "acct_missing"), "not found");
  const created = await AccountClient.createAccount(client, { name: "Travel", balance: 12.5, nickname: "Trips" });
  assert.equal(created.TAG, "Ok");
  assert.equal(created._0.nickname, "Trips");
});

test("express example: health and bearer-protected routes", async () => {
  assert.deepEqual(await (await exampleRequest("/health")).json(), { status: "ok" });
  assert.equal((await exampleRequest("/protected")).status, 401);
  assert.equal((await exampleRequest("/protected", { headers: { authorization: "Bearer wrong" } })).status, 401);
  const res = await exampleRequest("/protected", { headers: { authorization: `Bearer ${secret}` } });
  assert.equal(await res.text(), "secret");
});
