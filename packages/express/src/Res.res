// Express's response object.
type t

@send external status: (t, int) => t = "status"
@send external json: (t, JSON.t) => unit = "json"
@send external send: (t, string) => unit = "send"
@send external setHeader: (t, string, string) => t = "set"
