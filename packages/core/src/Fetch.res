// Fetch API bindings shared by the client and server adapters.

module AbortSignal = {
  type t

  /** A signal that aborts after the given number of milliseconds. */
  @scope("AbortSignal") @val external timeout: int => t = "timeout"
}

module AbortController = {
  type t

  @new external make: unit => t = "AbortController"
  @get external signal: t => AbortSignal.t = "signal"
  @send external abort: t => unit = "abort"
}

module Request = {
  type t
  type init = {method?: string, headers?: dict<string>, body?: string, signal?: AbortSignal.t}

  @new external make: (string, ~init: init=?) => t = "Request"
}

module Response = {
  type t
  type init = {status?: int, headers?: dict<string>}

  @scope("Response") @val external json: (JSON.t, ~init: init=?) => t = "json"
  @new external text: (string, ~init: init=?) => t = "Response"
  @get external status: t => int = "status"
  @get external ok: t => bool = "ok"
  @send external readText: t => promise<string> = "text"

  type headers
  @get external headers: t => headers = "headers"
  @send @return(nullable) external getHeader: (headers, string) => option<string> = "get"

  /** Mutates in place. Throws on immutable responses, such as one returned by `fetch()`. */
  @send external setHeader: (headers, string, string) => unit = "set"
  let setHeader = (response, name, value) => {
    response->headers->setHeader(name, value)
    response
  }
  let header = (response, name) => response->headers->getHeader(name)
}
