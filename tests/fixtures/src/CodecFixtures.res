// Codecs built from Codec's combinators, for tests/codec.test.mjs.
open ResApi

type role = | @as("owner") Owner | @as("advisor") Advisor

let roleCodec = Codec.enum(
  ~values=[Owner, Advisor],
  ~toString=role => (role :> string),
  ~name="role",
)

type member = {name: string, role: role, nickname: option<string>, age: int}

let memberCodec = Codec.object(
  ~decode=fields => {
    name: fields->Codec.field("name", Codec.string),
    role: fields->Codec.field("role", roleCodec),
    nickname: fields->Codec.field("nickname", Codec.option(Codec.string)),
    age: fields->Codec.field("age", Codec.int),
  },
  ~encode=({name, role, nickname, age}) => [
    ("name", Codec.string.encode(name)),
    ("role", roleCodec.encode(role)),
    ("nickname", Codec.option(Codec.string).encode(nickname)),
    ("age", Codec.int.encode(age)),
  ],
)

type team = {lead: member, members: array<member>}

let teamCodec = Codec.object(
  ~decode=fields => {
    lead: fields->Codec.field("lead", memberCodec),
    members: fields->Codec.field("members", Codec.array(memberCodec)),
  },
  ~encode=({lead, members}) => [
    ("lead", memberCodec.encode(lead)),
    ("members", Codec.array(memberCodec).encode(members)),
  ],
)

let nameCodec =
  Codec.string->Codec.refine(
    name => name->String.trim == "" ? Error("Expected a name") : Ok(name->String.trim),
    name => name,
  )

type params = {id: string}

let paramsCodec = Codec.object(
  ~decode=fields => {id: fields->Codec.field("id", Codec.string)},
  ~encode=({id}) => [("id", Codec.string.encode(id))],
)

// Built at load: route checking must accept an object codec whose fields match the route.
let getMember = Endpoint.get("/members/:id", ~params=paramsCodec, ~response=memberCodec)
