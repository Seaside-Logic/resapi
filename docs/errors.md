# Errors

resAPI keeps four kinds of failure apart: invalid requests, declared application errors, unexpected server failures, and failures on the client's side of the call. Each has its own status, wire format and client variant.

## On the server

A typed endpoint (`Router.register`) handles a request in this order. The first failure answers it.

| Step | Failure | Response |
| --- | --- | --- |
| 1. Decode path params (the body is not read yet) | Codec rejects them | 400 `invalid_params` |
| 2. Read the body (POST) | Stream error, aborted request | 500 `internal` |
| 3. Parse the body as JSON | Not valid JSON, or empty | 400 `malformed_json` |
| 4. Decode the body | Codec rejects it | 400 `invalid_body` |
| 5. Run the handler | `Error(e)`, a declared error | `errorStatus(e)` with `{"applicationError": ...}` |
| | An exception, or a rejected promise | 500 `internal` |
| 6. Encode the result | A codec throws, or `errorStatus` isn't 400–599 | 500 `internal` |

**Auth middleware runs first.** Middleware mounted with `Router.use` runs before resAPI's pipeline, so an auth rejection (`Reject`, or any middleware's own 401/403) comes before params and body are checked.

Validation errors and internal errors share one body format:

```json
{"error": {"kind": "invalid_body", "message": "Expected string", "path": ["name"]}}
```

`path` names the field that failed, as in `["owner", "name"]` or `["tags", "1"]`. It is `[]` when the failure isn't about one field.

A declared application error is sent with the status its contract maps it to, and its encoded value:

```json
{"applicationError": "not_found"}
```

The two keys can't be confused, so a client always knows whether a failure was declared.

### Unexpected exceptions

resAPI handles every exception inside a typed endpoint itself:

- The exception is logged with `console.error`, as the JS `Error` when there is one, so the stack trace survives.
- The caller gets `500 {"error": {"kind": "internal", "message": "Internal Server Error", "path": []}}`, which reveals no detail.
- The exception does **not** reach Hono's `onError` or Express's error middleware. Behaviour is therefore the same on both adapters.

Plain routes (`Router.get`/`post`) and middleware keep their framework's own error handling. resAPI only rethrows raw ReScript exceptions as JS `Error`s, so that Hono handles them at all and Express logs a stack. Both frameworks then answer with a plain 500. Express's default handler puts the stack in the response body unless `NODE_ENV=production`.

On Express, body-parser failures happen before resAPI runs and come back in Express's format: a body over the size limit (413), an unsupported charset (415), or malformed JSON rejected by an upstream `express.json()` (400). See the [Express guide](express.md#request-bodies).

### Content type

A typed POST accepts any content type, as long as the body is valid JSON. resAPI never answers 415.

## On the client

`Client.call` and `Client.callWithBody` return `result<'response, Client.error<'e>>`, where `'e` is the contract's declared error type:

| Variant | When |
| --- | --- |
| `Application({status, error})` | The server sent a declared error, and it decoded with the contract's error codec |
| `Unauthorized({status, reason})` | A 401 or 403 that isn't a declared error, from any middleware. `reason` is set when the body is a resAPI `Reject` with a message |
| `UnexpectedStatus({status, body})` | Any other non-2xx response: resAPI's own 400s and 500s, framework errors, proxies. `body` is the raw text |
| `InvalidResponse({path, message})` | The response broke the contract: a 2xx body that isn't JSON or fails the response codec, an `applicationError` that fails the error codec, or an `applicationError` from an endpoint that declares none |
| `Network(message)` | `fetch` itself failed: DNS, connection refused, CORS |
| `Aborted` | The call's `~signal` aborted or timed out |

**Programmer errors throw.** An invalid `baseUrl`, a missing or non-scalar path param, or a codec that throws while encoding makes the call reject with a JS `Error`. They're bugs in the calling code, and nothing was sent.

### How a failed response is classified

1. A body with `"applicationError"` is the contract's declared error, at any status, including 401 and 403. If it doesn't decode, or the endpoint declares no errors, it's `InvalidResponse`.
2. Otherwise, a 401 or 403 is `Unauthorized`. `reason` is `Some(message)` when the body is resAPI's rejection shape (`kind` `"unauthenticated"` or `"forbidden"`, from `Reject`) with a non-empty message. Otherwise it's `None`, for plain text, HTML or any other JSON.
3. Anything else non-2xx is `UnexpectedStatus`.

A typical match handles the cases the caller cares about, then falls back to `Client.message`:

```rescript
switch await client->Client.call(AccountApi.getAccount, ~params={id: id}) {
| Ok(account) => Ok(account)
| Error(Application({error: NotFound})) => Error("No such account.")
| Error(Unauthorized({reason: Some("mfa_required"), _})) => Error("Turn on two-factor authentication first.")
| Error(error) => Error(Client.message(error, ~declared=_ => "That didn't work."))
}
```
