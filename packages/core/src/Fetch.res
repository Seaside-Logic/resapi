// A source-compatible subset of @rescript/webapi's Fetch bindings, so code written against ResApi.Fetch
// keeps compiling when this module becomes re-exports of webapi (planned for ReScript 13).
//
// Rule: only names that exist in webapi, with its module paths, labels, argument order, return types and
// record fields. Leave things out; never change them. resAPI's own conveniences live elsewhere.
//
// Mirrored from rescript-lang/experimental-rescript-webapi main as of 2026-10-11 (alpha build b1d58f9):
// src/fetch/{Request,Response,Headers,HeadersInit,BodyInit,Fetch}.res, src/event/{AbortSignal,
// AbortController}.res. Re-checked for 0.2.0 against main b46bc2c on 2026-10-11: those files are unchanged.
// Re-check it at every resAPI release (docs/release-process.md).
// Abstract types (Headers.t, AbortSignal.t) are subsets of webapi's records: the re-export adds
// `type t = WebAPI.FetchTypes.headers` and `type t = WebAPI.DOM.abortSignal`.

module AbortSignal = {
  type t
  @scope("AbortSignal") external abort: (~reason: JSON.t=?) => t = "abort"
  @scope("AbortSignal") external timeout: int => t = "timeout"
  @scope("AbortSignal") external any: array<t> => t = "any"
}

module AbortController = {
  type t = private {signal: AbortSignal.t}
  @new external make: unit => t = "AbortController"
  @send external abort: (t, ~reason: JSON.t=?) => unit = "abort"
}

module Headers = {
  type t
  @new external make: unit => t = "Headers"
  @new external fromDict: dict<string> => t = "Headers"
  @send external append: (t, ~name: string, ~value: string) => unit = "append"
  @send external delete: (t, string) => unit = "delete"
  @send external get: (t, string) => Null.t<string> = "get"
  @send external has: (t, string) => bool = "has"
  @send external set: (t, ~name: string, ~value: string) => unit = "set"
}

// Mirrored from webapi: its union-typed init values are bound as abstract types with %identity
// constructors. The only casts allowed in resAPI (see AGENTS.md).
module HeadersInit = {
  type t
  external fromDict: dict<string> => t = "%identity"
  external fromHeaders: Headers.t => t = "%identity"
  external fromKeyValueArray: array<(string, string)> => t = "%identity"
}

module BodyInit = {
  type t
  external fromString: string => t = "%identity"
}

module Request = {
  type t = private {
    method: string,
    url: string,
    headers: Headers.t,
    signal: AbortSignal.t,
    bodyUsed: bool,
  }
  type requestInit = {
    mutable method?: string,
    mutable headers?: HeadersInit.t,
    mutable body?: Nullable.t<BodyInit.t>,
    mutable signal?: Nullable.t<AbortSignal.t>,
  }
  @new external fromURL: (string, ~init: requestInit=?) => t = "Request"
  @send external json: t => promise<JSON.t> = "json"
  @send external text: t => promise<string> = "text"
  @send external clone: t => t = "clone"
}

module Response = {
  type t = private {
    status: int,
    ok: bool,
    statusText: string,
    url: string,
    redirected: bool,
    headers: Headers.t,
    bodyUsed: bool,
  }
  type responseInit = {
    mutable status?: int,
    mutable statusText?: string,
    mutable headers?: HeadersInit.t,
  }
  @new external fromNull: (@as(json`null`) _, ~init: responseInit=?) => t = "Response"
  @new external fromString: (string, ~init: responseInit=?) => t = "Response"
  @scope("Response") external jsonR: (~data: JSON.t, ~init: responseInit=?) => t = "json"
  @send external json: t => promise<JSON.t> = "json"
  @send external text: t => promise<string> = "text"
  @send external clone: t => t = "clone"
}

external fetch: (string, ~init: Request.requestInit=?) => promise<Response.t> = "fetch"
external fetchWithRequest: (Request.t, ~init: Request.requestInit=?) => promise<Response.t> =
  "fetch"
