// Codec's combinators: decoding, error paths, encoding, and route checking with an object codec.
import { test } from "node:test";
import assert from "node:assert/strict";
import * as Codec from "../packages/core/src/Codec.res.mjs";
import * as RouteCheck from "../packages/core/src/RouteCheck.res.mjs";
import * as F from "./fixtures/src/CodecFixtures.res.mjs";

const ok = value => ({ TAG: "Ok", _0: value });
const err = (path, message) => ({ TAG: "Error", _0: { path, message } });
const ann = { name: "Ann", role: "owner", nickname: "A", age: 40 };

test("primitives decode their JSON type and reject others", () => {
  assert.deepEqual(Codec.string.decode("x"), ok("x"));
  assert.deepEqual(Codec.string.decode(1), err([], "Expected string"));
  assert.deepEqual(Codec.bool.decode(true), ok(true));
  assert.deepEqual(Codec.float.decode(1.5), ok(1.5));
  assert.deepEqual(Codec.int.decode(42), ok(42));
  assert.deepEqual(Codec.int.decode(1.5), err([], "Expected integer"));
  assert.deepEqual(Codec.int.decode(2147483648), err([], "Expected integer"));
  assert.deepEqual(Codec.int.decode(-2147483648), ok(-2147483648));
});

test("enum decodes listed values by their wire string, and nothing else", () => {
  assert.deepEqual(F.roleCodec.decode("advisor"), ok("advisor"));
  assert.deepEqual(F.roleCodec.decode("admin"), err([], "Expected role"));
  assert.deepEqual(F.roleCodec.decode("constructor"), err([], "Expected role"));
  assert.equal(F.roleCodec.encode("owner"), "owner");
});

test("object builds the record; option fields may be null or missing", () => {
  assert.deepEqual(F.memberCodec.decode(ann), ok(ann));
  const { nickname, ...noNickname } = ann;
  assert.deepEqual(F.memberCodec.decode(noNickname), ok({ ...noNickname, nickname: undefined }));
  assert.deepEqual(F.memberCodec.decode({ ...ann, nickname: null }), ok({ ...ann, nickname: undefined }));
});

test("object errors name the field; a missing required field says so", () => {
  assert.deepEqual(F.memberCodec.decode({ ...ann, role: "admin" }), err(["role"], "Expected role"));
  const { age, ...noAge } = ann;
  assert.deepEqual(F.memberCodec.decode(noAge), err(["age"], "Missing field"));
  assert.deepEqual(F.memberCodec.decode([]), err([], "Expected object"));
});

test("inherited keys are not fields", () => {
  const { name, ...noName } = ann;
  assert.deepEqual(F.memberCodec.decode(JSON.parse(JSON.stringify(noName))), err(["name"], "Missing field"));
  assert.deepEqual(F.paramsCodec.decode({ id: "x", constructor: 1 }), ok({ id: "x" }));
});

test("nested objects and arrays build the full path", () => {
  const team = { lead: ann, members: [ann, { ...ann, age: "old" }] };
  assert.deepEqual(F.teamCodec.decode(team), err(["members", "1", "age"], "Expected integer"));
  assert.deepEqual(F.teamCodec.decode({ lead: { ...ann, role: 1 }, members: [] }), err(["lead", "role"], "Expected role"));
});

test("encoding round-trips, with None as null", () => {
  const team = { lead: ann, members: [{ ...ann, nickname: undefined }] };
  const json = F.teamCodec.encode(team);
  assert.deepEqual(json.members[0].nickname, null);
  assert.deepEqual(F.teamCodec.decode(json), ok(team));
});

test("refine validates and converts after decoding", () => {
  assert.deepEqual(F.nameCodec.decode("  Smiths "), ok("Smiths"));
  assert.deepEqual(F.nameCodec.decode("   "), err([], "Expected a name"));
  assert.deepEqual(F.nameCodec.decode(3), err([], "Expected string"));
});

test("route checking accepts an object params codec that matches, rejects one that doesn't", () => {
  assert.ok(F.getMember);
  assert.equal(RouteCheck.check("/members/:id", F.paramsCodec), "Valid");
  assert.equal(RouteCheck.check("/members/:memberId", F.paramsCodec).TAG, "Invalid");
});
