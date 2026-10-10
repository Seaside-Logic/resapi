// Checks at contract construction that a route's `:params` and its params codec agree. Works with any
// Codec.t, without metadata: it probes the codec. Decode an object with every route param set to "x",
// encode the result back, and compare its keys with the route's params.
//
// A codec that refines strings (uuid, int parsing) rejects "x" at a field the route does have. That is
// inconclusive, not a mismatch: CannotValidate. The decode probe still catches a codec field missing
// from the route when it is the first error reported, but route params the codec ignores go unnoticed.

type outcome = Valid | Invalid(string) | CannotValidate(string)

let paramName = /^:([A-Za-z_][A-Za-z0-9_]*)$/
let unsupportedChars = /[:*{}?]/

/** The route's param names, or the first segment this checker doesn't understand
    (Hono wildcards, regex params, optional params). */
let parse = (path): result<array<string>, string> =>
  path
  ->String.split("/")
  ->Array.reduce(Ok([]), (acc, segment) =>
    acc->Result.flatMap(names =>
      switch paramName->RegExp.exec(segment) {
      | Some(match) =>
        switch match[1] {
        | Some(Some(name)) => Ok([...names, name])
        | _ => Error(segment)
        }
      | None => unsupportedChars->RegExp.test(segment) ? Error(segment) : Ok(names)
      }
    )
  )

let keysOf = (json: JSON.t) =>
  switch json {
  | Object(d) => d->Dict.keysToArray
  | _ => []
  }

let probe = (names, codec: Codec.t<_>) => {
  let input = JSON.Object(names->Array.map(n => (n, JSON.String("x")))->Dict.fromArray)
  switch codec.decode(input) {
  | Error({path, message})
    if path->Array.get(0)->Option.mapOr(false, field => names->Array.includes(field)) =>
    CannotValidate(
      `params codec rejected the probe value at [${path->Array.join(".")}]: ${message}`,
    )
  | Error({path, message}) =>
    Invalid(
      `params codec rejected {${names->Array.join(", ")}} at [${path->Array.join(
          ".",
        )}]: ${message}`,
    )
  | Ok(decoded) =>
    let keys = keysOf(codec.encode(decoded))
    let missing = names->Array.filter(n => !(keys->Array.includes(n)))
    let unexpected = keys->Array.filter(k => !(names->Array.includes(k)))
    missing == [] && unexpected == []
      ? Valid
      : Invalid(
          `codec lacks [${missing->Array.join(", ")}], route lacks [${unexpected->Array.join(
              ", ",
            )}]`,
        )
  }
}

let check = (path, codec) =>
  switch parse(path) {
  | Error(segment) =>
    Invalid(
      `unsupported route syntax in segment "${segment}" (only literal segments and :name params)`,
    )
  | Ok(names) =>
    switch names->Array.find(n => names->Array.indexOf(n) != names->Array.lastIndexOf(n)) {
    | Some(name) => Invalid(`duplicate route param :${name}`)
    | None => probe(names, codec)
    }
  }

/** Throws on Invalid, so a bad top-level contract stops the module (and the Worker) from loading. */
let assertValid = (path, codec) =>
  switch check(path, codec) {
  | Invalid(details) => JsError.throwWithMessage(`Invalid route "${path}": ${details}`)
  | Valid | CannotValidate(_) => ()
  }
