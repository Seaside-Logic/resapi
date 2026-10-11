// Express's request object.
type t

/** Path parameters, already percent-decoded by Express. */
@get external params: t => dict<string> = "params"

/** Set by body-parsing middleware: a string from `express.text`, parsed JSON from `express.json`. */
@get external body: t => Nullable.t<JSON.t> = "body"

@send @return(nullable) external header: (t, string) => option<string> = "get"
@get external method: t => string = "method"
@get external path: t => string = "path"

/** Stores a value on the request under `key` (as `req[name]`), usually in middleware. The name shares
    `req` with Express's own fields: a getter such as `query` or `path` throws, and a field Express writes,
    such as `params` or `body`, gets overwritten. Pick a name Express doesn't use. */
let set: (t, ResApi.Key.t<'a>, 'a) => unit

/** The value under `key` (`req[name]`), or `None` when it's unset, `undefined` or `null`. */
let get: (t, ResApi.Key.t<'a>) => option<'a>

/** For routes behind the middleware that sets `key`. Throws when the value is missing: a logged 500
    that reveals nothing, inside a typed endpoint. */
let getOrThrow: (t, ResApi.Key.t<'a>) => 'a
