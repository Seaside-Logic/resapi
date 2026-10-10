// Sury schema -> resAPI codec. Compiles both directions immediately: call `make` at module top level,
// because Workers forbid the `new Function` that Sury uses once a request is running.
let pathSegment = (segment: S.Path.propertyKey) =>
  switch segment {
  | String(key) => key
  | Number(index) => index->Float.toString
  }

let make = (schema: S.t<'a>): ResApi.Codec.t<'a> => {
  let parse: JSON.t => _ = S.compileParseAsResult(~to=schema)
  let encode = S.compileConvertOrThrow(~from=schema, ~to=S.json)
  {
    decode: json =>
      parse(json)->Result.mapError((e): ResApi.Codec.error => {
        path: e.path->Array.map(pathSegment),
        message: e.reason,
      }),
    encode,
  }
}
