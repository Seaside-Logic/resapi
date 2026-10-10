// Express's request object.
type t

/** Path parameters, already percent-decoded by Express. */
@get external params: t => dict<string> = "params"

/** Set by body-parsing middleware: a string from `express.text`, parsed JSON from `express.json`. */
@get external body: t => Nullable.t<JSON.t> = "body"

@send @return(nullable) external header: (t, string) => option<string> = "get"
@get external method: t => string = "method"
@get external path: t => string = "path"
