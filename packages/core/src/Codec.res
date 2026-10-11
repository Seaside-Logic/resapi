// The only thing an endpoint needs from a codec. Any backend fits: Sury via @resapi/sury, a hand-written
// record, or the combinators below.
type error = {path: array<string>, message: string}
type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}

let unit = {decode: _ => Ok(), encode: () => JSON.Object(dict{})}

let fail = (message): result<_, error> => Error({path: [], message})

// The failed value's position, in front of the inner path: ["2", "role"].
let under = (segment, error: error) => {...error, path: [segment, ...error.path]}

let string = {
  decode: json =>
    switch json {
    | JSON.String(s) => Ok(s)
    | _ => fail("Expected string")
    },
  encode: s => JSON.String(s),
}

let float = {
  decode: json =>
    switch json {
    | JSON.Number(n) => Ok(n)
    | _ => fail("Expected number")
    },
  encode: n => JSON.Number(n),
}

@scope("Number") @val external isSafeInteger: float => bool = "isSafeInteger"

// int is 32-bit: a larger JSON integer is rejected rather than wrapped.
let int = {
  decode: json =>
    switch json {
    | JSON.Number(n) if isSafeInteger(n) && n >= -2147483648. && n <= 2147483647. =>
      Ok(n->Float.toInt)
    | _ => fail("Expected integer")
    },
  encode: n => JSON.Number(n->Int.toFloat),
}

let bool = {
  decode: json =>
    switch json {
    | JSON.Boolean(b) => Ok(b)
    | _ => fail("Expected boolean")
    },
  encode: b => JSON.Boolean(b),
}

// A linear search: value lists are short, and a lookup object would match inherited keys such as
// "constructor".
let enum = (~values, ~toString, ~name="one of the allowed values") => {
  decode: json =>
    switch json {
    | JSON.String(s) =>
      switch values->Array.find(value => toString(value) == s) {
      | Some(value) => Ok(value)
      | None => fail(`Expected ${name}`)
      }
    | _ => fail(`Expected ${name}`)
    },
  encode: value => JSON.String(toString(value)),
}

let array = codec => {
  decode: json =>
    switch json {
    | JSON.Array(items) =>
      items->Array.reduceWithIndex(Ok([]), (acc, item, index) =>
        acc->Result.flatMap(values =>
          switch codec.decode(item) {
          | Ok(value) => Ok([...values, value])
          | Error(error) => Error(under(index->Int.toString, error))
          }
        )
      )
    | _ => fail("Expected array")
    },
  encode: values => JSON.Array(values->Array.map(codec.encode)),
}

let option = codec => {
  decode: json =>
    switch json {
    | JSON.Null => Ok(None)
    | json => codec.decode(json)->Result.map(value => Some(value))
    },
  encode: value =>
    switch value {
    | None => JSON.Null
    | Some(value) => codec.encode(value)
    },
}

let refine = (codec, check, back) => {
  decode: json =>
    codec.decode(json)->Result.flatMap(value =>
      check(value)->Result.mapError(message => {path: [], message})
    ),
  encode: value => codec.encode(back(value)),
}

type fields = dict<JSON.t>

// Raised by `field` and caught by `object`, so a record decoder reads as a record literal. Never
// escapes `object`.
exception FieldError(error)

@scope("Object") @val external hasOwn: (dict<JSON.t>, string) => bool = "hasOwn"

// A missing field decodes as null: `option` fields become None, required ones fail as missing.
let field = (fields, key, codec) => {
  let json = hasOwn(fields, key) ? fields->Dict.get(key) : None
  switch (json, codec.decode(json->Option.getOr(JSON.Null))) {
  | (_, Ok(value)) => value
  | (Some(_), Error(error)) => throw(FieldError(under(key, error)))
  | (None, Error(_)) => throw(FieldError({path: [key], message: "Missing field"}))
  }
}

let object = (~decode, ~encode) => {
  decode: json =>
    switch json {
    | JSON.Object(fields) =>
      try Ok(decode(fields)) catch {
      | FieldError(error) => Error(error)
      }
    | _ => fail("Expected object")
    },
  encode: value => JSON.Object(encode(value)->Dict.fromArray),
}
