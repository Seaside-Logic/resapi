// The only thing an endpoint needs from a codec. Any backend fits: Sury via @resapi/sury, or a hand-written record.
type error = {path: array<string>, message: string}
type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}

/** For endpoints without path params or without a request body. */
let unit = {decode: _ => Ok(), encode: () => JSON.Object(dict{})}
