// Typed application errors end to end: the client calls the Hono app in-process with the shared contracts.
import { test } from "node:test";
import assert from "node:assert/strict";
import * as Client from "../packages/core/src/Client.res.mjs";
import * as TestApi from "./fixtures/src/TestApi.res.mjs";
import { app } from "./fixtures/src/TestApp.res.mjs";

const client = Client.make("http://localhost/", request => app.fetch(request));

test("success decodes to Ok", async () => {
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "a1" }), { TAG: "Ok", _0: { id: "a1", name: "Ann" } });
});

test("server's NotFound arrives as Application NotFound with 404", async () => {
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "missing" }), {
    TAG: "Error",
    _0: { TAG: "Application", status: 404, error: "NotFound" },
  });
});

test("server's AccessDenied arrives as Application AccessDenied with 403", async () => {
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "secret" }), {
    TAG: "Error",
    _0: { TAG: "Application", status: 403, error: "AccessDenied" },
  });
});

test("a server-side internal error is UnexpectedStatus 500 and reveals nothing", async t => {
  t.mock.method(console, "error", () => {});
  const result = await Client.call(client, TestApi.brokenEncoder, undefined);
  assert.equal(result._0.TAG, "UnexpectedStatus");
  assert.equal(result._0.status, 500);
  assert.doesNotMatch(result._0.body, /secret internal detail/);
});

test("a network failure stays Network", async () => {
  const offline = Client.make("http://localhost/", async () => { throw new TypeError("offline"); });
  assert.deepEqual(await Client.call(offline, TestApi.getAccount, { id: "a1" }), {
    TAG: "Error",
    _0: { TAG: "Network", _0: "offline" },
  });
});
