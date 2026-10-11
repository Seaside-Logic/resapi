// Express's request object.
type t

/** Path parameters, already percent-decoded by Express. */
@get external params: t => dict<string> = "params"

/** Set by body-parsing middleware: a string from `express.text`, parsed JSON from `express.json`. */
@get external body: t => Nullable.t<JSON.t> = "body"

@send @return(nullable) external header: (t, string) => option<string> = "get"
@get external method: t => string = "method"
@get external path: t => string = "path"

@get_index external field: (t, string) => Nullable.t<'a> = ""
@set_index external setField: (t, string, 'a) => unit = ""

let set = (req, key, value) => req->setField(ResApi.Key.name(key), value)
let get = (req, key) => req->field(ResApi.Key.name(key))->Nullable.toOption
let getOrThrow = (req, key) => req->get(key)->ResApi.Key.orThrow(key)
