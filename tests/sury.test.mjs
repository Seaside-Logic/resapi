// SuryCodec adapts a Sury schema to Codec.t; errors keep Sury's field path.
import { test } from "node:test";
import assert from "node:assert/strict";
import * as S from "sury";
import * as SuryCodec from "../packages/sury/src/SuryCodec.res.mjs";

const codec = SuryCodec.make(
  S.schema({ id: S.string, owner: { name: S.string }, tags: S.array(S.string), balance: S.number }),
);
const valid = { id: "a1", owner: { name: "Ann" }, tags: ["x"], balance: 1.5 };

test("decodes valid JSON", () => {
  assert.deepEqual(codec.decode(valid), { TAG: "Ok", _0: valid });
});

test("encodes to JSON", () => {
  assert.deepEqual(codec.encode(valid), valid);
});

test("error path names the nested field", () => {
  const result = codec.decode({ ...valid, owner: { name: 7 } });
  assert.equal(result.TAG, "Error");
  assert.deepEqual(result._0.path, ["owner", "name"]);
  assert.ok(result._0.message.length > 0);
});

test("error path includes array indexes as strings", () => {
  const result = codec.decode({ ...valid, tags: ["x", 2] });
  assert.deepEqual(result._0.path, ["tags", "1"]);
});

test("missing field is reported at that field", () => {
  const { balance, ...rest } = valid;
  assert.deepEqual(codec.decode(rest)._0.path, ["balance"]);
});

test("non-object input is reported at the root", () => {
  assert.deepEqual(codec.decode("nope")._0.path, []);
});
