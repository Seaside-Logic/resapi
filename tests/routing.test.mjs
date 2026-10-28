// Router.all, Context.request, Router.notFound and assertRegistered on both adapters.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import * as HonoRouter from "../packages/hono/src/Router.res.mjs";
import * as ExpressRouter from "../packages/express/src/Router.res.mjs";
import * as Endpoint from "../packages/core/src/Endpoint.res.mjs";
import * as TestApi from "./fixtures/src/TestApi.res.mjs";
import { routingApp } from "./fixtures/src/TestApp.res.mjs";
import { routingApp as expressRoutingApp, app as expressApp } from "./fixtures/src/ExpressTestApp.res.mjs";

const hono = (path, init) => routingApp.fetch(new Request(`http://localhost${path}`, init));

test("hono: Router.all serves every method, and Context.request is the Fetch request", async () => {
  for (const method of ["GET", "POST", "PUT", "DELETE"]) {
    const res = await hono("/proxy/a/b", { method });
    assert.equal(await res.text(), `${method} http://localhost/proxy/a/b`);
  }
});

test("hono: Router.notFound answers unmatched requests", async () => {
  const res = await hono("/nope");
  assert.equal(res.status, 404);
  assert.deepEqual(await res.json(), { error: "not_found" });
  assert.equal((await hono("/accounts/a1")).status, 200);
});

test("hono: assertRegistered passes for registered endpoints and names the missing ones", () => {
  HonoRouter.assertRegistered(routingApp, [Endpoint.any(TestApi.getAccount)]);
  assert.throws(
    () => HonoRouter.assertRegistered(routingApp, [Endpoint.any(TestApi.getAccount), Endpoint.any(TestApi.createAccount), Endpoint.any(TestApi.addMember), Endpoint.any(TestApi.updateAccount)]),
    { message: "Endpoints without a route: POST /accounts, POST /orgs/:org/members/:member, PUT /accounts/:id" },
  );
});

test("express: Router.all serves every method", async () => {
  const server = expressRoutingApp.listen(0);
  await once(server, "listening");
  after(() => server.close());
  const base = `http://localhost:${server.address().port}`;
  for (const method of ["GET", "POST", "PUT", "DELETE"]) {
    assert.equal(await (await fetch(`${base}/proxy/x`, { method })).text(), method);
  }
});

test("express: assertRegistered tracks register calls", () => {
  ExpressRouter.assertRegistered(expressApp, [Endpoint.any(TestApi.getAccount), Endpoint.any(TestApi.createAccount), Endpoint.any(TestApi.updateAccount)]);
  assert.throws(
    () => ExpressRouter.assertRegistered(expressRoutingApp, [Endpoint.any(TestApi.getAccount)]),
    { message: "Endpoints without a route: GET /accounts/:id" },
  );
});
