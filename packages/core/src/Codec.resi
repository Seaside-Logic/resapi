// The only thing an endpoint needs from a codec. Any backend fits: Sury via @resapi/sury, a hand-written
// record, or the combinators below.

/** Where decoding failed (field names and array indexes, outermost first) and why. */
type error = {path: array<string>, message: string}

type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}

/** For endpoints without path params or without a request body. Decodes anything, encodes `{}`. */
let unit: t<unit>

let string: t<string>
let float: t<float>

/** Rejects non-integers and values outside the 32-bit range of ReScript's `int`. */
let int: t<int>

let bool: t<bool>

/** A value from a fixed set, sent as a string. With `@as` variants, `~toString=v => (v :> string)` keeps
    the wire names in the type and is compiler-checked. List every value in `~values`: a missing one fails
    to decode, so cover it with a round-trip test. */
let enum: (~values: array<'a>, ~toString: 'a => string, ~name: string=?) => t<'a>

/** Errors carry the index: `["2", "role"]`. */
let array: t<'a> => t<array<'a>>

/** `null`, or a missing field inside `object`, is `None`. `None` encodes as `null`. */
let option: t<'a> => t<option<'a>>

/** Validates or converts after decoding: `Error(message)` fails at this value's path. `back` converts
    for encoding. */
let refine: (t<'a>, 'a => result<'b, string>, 'b => 'a) => t<'b>

/** An object's fields, readable only inside `object`'s `~decode`. */
type fields

/** A field's value. Failures carry the field name in their path; a missing field that isn't an `option`
    fails as "Missing field". Only call it inside `object`'s `~decode`. */
let field: (fields, string, t<'a>) => 'a

/** A record codec. Decode by building the record literal from `field`s, so a field left out is a
    compile error. Encode by listing every field as `(name, json)`. */
let object: (~decode: fields => 'a, ~encode: 'a => array<(string, JSON.t)>) => t<'a>
