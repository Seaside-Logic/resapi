// The Cloudflare example, through its own client. In-process by default; with RESAPI_BASE_URL set
// (scripts/test-worker.sh) every request goes over HTTP to the Worker under `wrangler dev` (workerd).
import { test } from "node:test";
import assert from "node:assert/strict";
import * as Client from "../packages/core/src/Client.res.mjs";
import * as AccountClient from "../examples/cloudflare/src/AccountClient.res.mjs";
import { app } from "../examples/cloudflare/src/App.res.mjs";

const secret = "test-secret";
const baseUrl = process.env.RESAPI_BASE_URL;
const send = baseUrl ? request => fetch(request) : request => app.fetch(request, { API_SECRET: secret });
const origin = baseUrl ?? "http://localhost";
const request = (path, init) => send(new Request(`${origin}${path}`, init));
const client = Client.make(origin, send);

test("simple route", async () => {
  const res = await request("/health");
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: "ok" });
});

test("typed endpoint decodes into the contract type (Sury codecs built at module load)", async () => {
  assert.deepEqual(await AccountClient.getAccount(client, "acct_123"), {
    TAG: "Ok",
    _0: { id: "acct_123", name: "Retirement Savings", balance: 250000, nickname: undefined },
  });
});

test("typed application error arrives as Application NotFound", async () => {
  assert.deepEqual(await AccountClient.getAccount(client, "acct_missing"), {
    TAG: "Error",
    // `@as("not_found") NotFound` is the string "not_found" at runtime.
    _0: { TAG: "Application", status: 404, error: "not_found" },
  });
  assert.deepEqual(await (await request("/accounts/acct_missing")).json(), { applicationError: "not_found" });
});

test("typed POST encodes the body and decodes the created account", async () => {
  const result = await AccountClient.createAccount(client, { name: "Travel", balance: 12.5, nickname: "Trips" });
  assert.equal(result.TAG, "Ok");
  assert.equal(result._0.name, "Travel");
  assert.equal(result._0.nickname, "Trips");
});

test("an invalid request body is a 400 with the field path", async () => {
  const res = await request("/accounts", { method: "POST", body: JSON.stringify({ name: "X", balance: "lots" }) });
  assert.equal(res.status, 400);
  const { error } = await res.json();
  assert.equal(error.kind, "invalid_body");
  assert.deepEqual(error.path, ["balance"]);
});

test("protected route reads the typed API_SECRET binding", async () => {
  assert.equal((await request("/protected")).status, 401);
  assert.equal((await request("/protected", { headers: { authorization: "Bearer wrong" } })).status, 401);
  const res = await request("/protected", { headers: { authorization: `Bearer ${secret}` } });
  assert.equal(res.status, 200);
  assert.equal(await res.text(), "secret");
});

test("describe handles each outcome as a typed case", async () => {
  assert.equal(await AccountClient.describe(client, "acct_123"), "Retirement Savings: 250000");
  assert.equal(await AccountClient.describe(client, "acct_missing"), "not found");
  const offline = Client.make(origin, async () => { throw new TypeError("offline"); });
  assert.equal(await AccountClient.describe(offline, "acct_123"), "network error: offline");
  const lying = Client.make(origin, async () => Response.json({ id: "acct_123" }));
  assert.match(await AccountClient.describe(lying, "acct_123"), /^invalid response at \[name\]/);
});
