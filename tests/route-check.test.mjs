// Initialization-time route validation: route `:params` against the params codec.
import { test } from "node:test";
import assert from "node:assert/strict";
import * as S from "sury";
import * as RouteCheck from "../packages/core/src/RouteCheck.res.mjs";
import * as Endpoint from "../packages/core/src/Endpoint.res.mjs";
import * as Codec from "../packages/core/src/Codec.res.mjs";
import * as SuryCodec from "../packages/sury/src/SuryCodec.res.mjs";

const idCodec = SuryCodec.make(S.schema({ id: S.string }));
const memberCodec = SuryCodec.make(S.schema({ org: S.string, member: S.string }));
const uuidCodec = SuryCodec.make(S.schema({ id: S.uuid }));
const anyResponse = SuryCodec.make(S.unknown);

const invalid = (path, codec, pattern) => {
  const outcome = RouteCheck.check(path, codec);
  assert.equal(outcome.TAG, "Invalid", JSON.stringify(outcome));
  assert.match(outcome._0, pattern);
};

test("matching route and codec are Valid", () => {
  assert.equal(RouteCheck.check("/accounts/:id", idCodec), "Valid");
  assert.equal(RouteCheck.check("/orgs/:org/members/:member", memberCodec), "Valid");
});

test("a route with no params and Codec.unit is Valid", () => {
  assert.equal(RouteCheck.check("/health", Codec.unit), "Valid");
  assert.equal(RouteCheck.check("/", Codec.unit), "Valid");
});

test("a renamed param is Invalid", () => {
  invalid("/accounts/:accountId", idCodec, /rejected \{accountId\} at \[id\]/);
});

test("a route param the codec lacks is Invalid", () => {
  invalid("/accounts/:id/:extra", idCodec, /codec lacks \[extra\]/);
});

test("a codec field the route lacks is Invalid", () => {
  invalid("/accounts", idCodec, /rejected \{\} at \[id\]/);
  invalid("/orgs/:org", memberCodec, /at \[member\]/);
});

test("Codec.unit on a route with params is Invalid", () => {
  invalid("/accounts/:id", Codec.unit, /codec lacks \[id\]/);
});

test("a duplicate route param is Invalid", () => {
  invalid("/a/:id/b/:id", idCodec, /duplicate route param :id/);
});

test("Hono syntax the checker doesn't understand is Invalid, not silently accepted", () => {
  for (const path of ["/files/*", "/a/:id{[0-9]+}", "/a/:id?", "/a/b:id", "/a/:"]) {
    invalid(path, idCodec, /unsupported route syntax/);
  }
});

test("a refined codec that rejects the probe value is CannotValidate", () => {
  const outcome = RouteCheck.check("/accounts/:id", uuidCodec);
  assert.equal(outcome.TAG, "CannotValidate");
  assert.match(outcome._0, /at \[id\]/);
});

test("a refined codec still catches a codec field missing from the route", () => {
  invalid("/accounts/:accountId", uuidCodec, /at \[id\]/);
});

test("known gap: a refined codec misses a route param it ignores", () => {
  assert.equal(RouteCheck.check("/accounts/:id/:extra", uuidCodec).TAG, "CannotValidate");
});

test("Endpoint.get and Endpoint.post throw on Invalid, naming the route", () => {
  assert.throws(() => Endpoint.get("/accounts/:accountId", idCodec, anyResponse), /Invalid route "\/accounts\/:accountId"/);
  assert.throws(() => Endpoint.post("/accounts/:id", Codec.unit, anyResponse, anyResponse), /Invalid route "\/accounts\/:id"/);
});

test("Endpoint.get accepts Valid and CannotValidate routes", () => {
  assert.equal(Endpoint.get("/accounts/:id", idCodec, anyResponse).path, "/accounts/:id");
  assert.equal(Endpoint.get("/accounts/:id", uuidCodec, anyResponse).path, "/accounts/:id");
});

test("a module with a mismatched top-level contract fails to load", async () => {
  await assert.rejects(import("./fixtures/src/BadContract.res.mjs"), /Invalid route "\/accounts\/:accountId"/);
});
