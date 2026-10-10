// Typed client with an injected fetch: URL construction, request encoding and error classification.
import { test } from "node:test";
import assert from "node:assert/strict";
import * as Client from "../packages/core/src/Client.res.mjs";
import * as TestApi from "./fixtures/src/TestApi.res.mjs";

// A client whose fetch records each request and answers with `respond(request)`.
const recording = (baseUrl, respond = () => Response.json({ id: "a1", name: "Ann" })) => {
  const requests = [];
  const client = Client.make(baseUrl, async request => {
    requests.push(request);
    return respond(request);
  });
  return { client, requests };
};

const urlFor = async (baseUrl, contract, params) => {
  const { client, requests } = recording(baseUrl);
  await Client.call(client, contract, params);
  return requests[0].url;
};

test("the base URL keeps its path prefix, with or without a trailing slash", async () => {
  const { getAccount } = TestApi;
  assert.equal(await urlFor("https://x.dev", getAccount, { id: "1" }), "https://x.dev/accounts/1");
  assert.equal(await urlFor("https://x.dev/", getAccount, { id: "1" }), "https://x.dev/accounts/1");
  assert.equal(await urlFor("https://x.dev/api", getAccount, { id: "1" }), "https://x.dev/api/accounts/1");
  assert.equal(await urlFor("https://x.dev/api/", getAccount, { id: "1" }), "https://x.dev/api/accounts/1");
});

test("request URL keeps the base path prefix", async () => {
  assert.equal(await urlFor("https://example.com/api/", TestApi.getAccount, { id: "123" }), "https://example.com/api/accounts/123");
});

test("path params are percent-encoded", async () => {
  assert.equal(await urlFor("https://x.dev", TestApi.getAccount, { id: "a b/c?d" }), "https://x.dev/accounts/a%20b%2Fc%3Fd");
});

test("multiple params and number params fill their segments", async () => {
  assert.equal(await urlFor("https://x.dev", TestApi.getMember, { org: "acme", member: 42 }), "https://x.dev/orgs/acme/members/42");
});

test("GET decodes the response into the contract type", async () => {
  const { client, requests } = recording("https://x.dev");
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "a1" }), { TAG: "Ok", _0: { id: "a1", name: "Ann" } });
  assert.equal(requests[0].method, "GET");
});

test("POST sends the encoded body as JSON", async () => {
  const { client, requests } = recording("https://x.dev");
  const result = await Client.callWithBody(client, TestApi.createAccount, undefined, { name: "Ann" });
  assert.equal(result.TAG, "Ok");
  assert.equal(requests[0].method, "POST");
  assert.equal(requests[0].headers.get("content-type"), "application/json");
  assert.deepEqual(await requests[0].json(), { name: "Ann" });
});

test("a missing path param is InvalidParams and sends nothing", async () => {
  const { client, requests } = recording("https://x.dev");
  const result = await Client.call(client, TestApi.missingParam, "x");
  assert.equal(result._0.TAG, "InvalidParams");
  assert.match(result._0._0, /Missing path parameter "id"/);
  assert.equal(requests.length, 0);
});

test("a non-scalar path param is InvalidParams", async () => {
  const result = await Client.call(recording("https://x.dev").client, TestApi.nonScalarParam, "x");
  assert.equal(result._0.TAG, "InvalidParams");
  assert.match(result._0._0, /must be a string, number or boolean/);
});

test("a codec that throws while encoding is EncodeFailed, not Network", async () => {
  const result = await Client.call(recording("https://x.dev").client, TestApi.throwingParams, "x");
  assert.deepEqual(result, { TAG: "Error", _0: { TAG: "EncodeFailed", _0: "cannot encode" } });
});

test("a fetch failure is Network", async () => {
  const { client } = recording("https://x.dev", () => { throw new TypeError("connection refused"); });
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "a1" }), {
    TAG: "Error",
    _0: { TAG: "Network", _0: "connection refused" },
  });
});

test("client headers, resAPI's content-type and per-request headers merge, later ones winning", async () => {
  const requests = [];
  const client = Client.make("https://x.dev", async request => {
    requests.push(request);
    return Response.json({ id: "new", name: "Ann" });
  }, { Authorization: "Bearer default", "X-App": "demo", "Content-Type": "text/plain" });
  await Client.callWithBody(client, TestApi.createAccount, undefined, { name: "Ann" }, { authorization: "Bearer token" });
  const { headers } = requests[0];
  assert.equal(headers.get("authorization"), "Bearer token");
  assert.equal(headers.get("x-app"), "demo");
  assert.equal(headers.get("content-type"), "application/json");
  await Client.call(client, TestApi.getAccount, { id: "a1" }, { "X-Request-ID": "r1" });
  assert.equal(requests[1].headers.get("x-request-id"), "r1");
  assert.equal(requests[1].headers.get("authorization"), "Bearer default");
});

// A fake server that never answers, but rejects as fetch does when the request's signal aborts.
const hang = request =>
  new Promise((_, reject) => {
    const { signal } = request;
    if (signal.aborted) reject(signal.reason);
    signal.addEventListener("abort", () => reject(signal.reason));
  });

test("an aborted signal is Aborted, not Network", async () => {
  const { client } = recording("https://x.dev", hang);
  const controller = new AbortController();
  const pending = Client.call(client, TestApi.getAccount, { id: "a1" }, undefined, controller.signal);
  controller.abort();
  assert.deepEqual(await pending, { TAG: "Error", _0: "Aborted" });
});

test("a signal's timeout is Aborted", async () => {
  const { client } = recording("https://x.dev", hang);
  const result = await Client.call(client, TestApi.getAccount, { id: "a1" }, undefined, AbortSignal.timeout(5));
  assert.deepEqual(result, { TAG: "Error", _0: "Aborted" });
});

test("a non-2xx status is UnexpectedStatus with the body text", async () => {
  const { client } = recording("https://x.dev", () => new Response("nope", { status: 503 }));
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "a1" }), {
    TAG: "Error",
    _0: { TAG: "UnexpectedStatus", status: 503, body: "nope" },
  });
});

test("a response that doesn't match the contract is InvalidResponse with the field path", async () => {
  const { client } = recording("https://x.dev", () => Response.json({ id: "a1", name: 7 }));
  const result = await Client.call(client, TestApi.getAccount, { id: "a1" });
  assert.equal(result._0.TAG, "InvalidResponse");
  assert.deepEqual(result._0._0.path, ["name"]);
});

test("a non-JSON success response is InvalidResponse", async () => {
  const { client } = recording("https://x.dev", () => new Response("<html>"));
  const result = await Client.call(client, TestApi.getAccount, { id: "a1" });
  assert.equal(result._0.TAG, "InvalidResponse");
  assert.deepEqual(result._0._0.path, []);
});

test("an invalid base URL throws instead of posing as a request failure", async () => {
  await assert.rejects(Client.call(recording("not a url").client, TestApi.getAccount, { id: "a1" }), TypeError);
});

test("a declared application error decodes to Application with its status", async () => {
  const { client } = recording("https://x.dev", () => Response.json({ applicationError: "access_denied" }, { status: 403 }));
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "a1" }), {
    TAG: "Error",
    _0: { TAG: "Application", status: 403, error: "AccessDenied" },
  });
});

test("a malformed application error is InvalidResponse, with the path under applicationError", async () => {
  const { client } = recording("https://x.dev", () => Response.json({ applicationError: "on_fire" }, { status: 404 }));
  const result = await Client.call(client, TestApi.getAccount, { id: "a1" });
  assert.equal(result._0.TAG, "InvalidResponse");
  assert.deepEqual(result._0._0.path, ["applicationError"]);
});

test("an application error from an endpoint that declares none is InvalidResponse", async () => {
  const { client } = recording("https://x.dev", () => Response.json({ applicationError: "not_found" }, { status: 404 }));
  const result = await Client.callWithBody(client, TestApi.createAccount, undefined, { name: "Ann" });
  assert.equal(result._0.TAG, "InvalidResponse");
});

test("a framework error body is UnexpectedStatus, not an application error", async () => {
  const body = JSON.stringify({ error: { kind: "invalid_params", message: "x", path: [] } });
  const { client } = recording("https://x.dev", () => new Response(body, { status: 400 }));
  assert.deepEqual(await Client.call(client, TestApi.getAccount, { id: "a1" }), {
    TAG: "Error",
    _0: { TAG: "UnexpectedStatus", status: 400, body },
  });
});
