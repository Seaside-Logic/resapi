# Errors

resAPI distinguishes between invalid requests, declared application errors, unexpected server failures, and client failures. The sections below explain how each is reported over HTTP and to the typed client. The compiler catches many contract mismatches before a request is sent; see [Reading type errors](#reading-type-errors).

## On the server

A typed endpoint added with `Router.register` processes a request in the following order. If a step fails, resAPI sends the corresponding response and stops processing.

| Step | Failure | Response |
| --- | --- | --- |
| 1. Decode path parameters before reading the body | The parameter codec rejects the values | 400 `invalid_params` |
| 2. Read the POST body | The body stream fails or the request is aborted | 500 `internal` |
| 3. Parse the body as JSON | The body is empty or contains invalid JSON | 400 `malformed_json` |
| 4. Decode the body | The body codec rejects the value | 400 `invalid_body` |
| 5. Run the handler | The handler returns a declared error with `Error(e)` | `errorStatus(e)` with `{"applicationError": ...}` |
| | The handler throws or its promise rejects | 500 `internal` |
| 6. Encode the result | A codec throws or `errorStatus` returns a status outside 400–599 | 500 `internal` |

**Auth middleware runs first.** Register auth middleware with `Router.use` before your typed endpoints. It can reject the request with `Reject` or its own 401/403 response before resAPI checks the path parameters or body.

Validation errors and internal errors use the same response structure:

```json
{"error": {"kind": "invalid_body", "message": "Expected string", "path": ["name"]}}
```

`path` identifies the field that failed, for example `["owner", "name"]` or `["tags", "1"]`. An empty path (`[]`) means the failure isn't tied to a specific field.

For a declared application error, resAPI uses the status defined in the contract and sends the encoded error value:

```json
{"applicationError": "not_found"}
```

The separate `error` and `applicationError` keys let the client distinguish declared application errors from other failures.

### Unexpected exceptions

resAPI catches exceptions raised while processing a typed endpoint:

- The exception is logged with `console.error`. If it is a JavaScript `Error`, the original error object is logged to preserve its stack trace.
- The caller receives `500 {"error": {"kind": "internal", "message": "Internal Server Error", "path": []}}`, without the exception details.
- The exception does **not** reach Hono's `onError` or Express's error middleware. Both adapters handle it the same way.

Plain routes (`Router.get`/`post`) and middleware (`Router.use`) use the framework's error handling: Hono's `onError` or Express's error middleware. resAPI converts raw ReScript exceptions to JavaScript `Error` objects so Hono can handle them and Express can log a stack trace. Existing JavaScript errors, including Hono's `HTTPException`, pass through unchanged. By default, both frameworks log unhandled errors and return HTTP 500. Express also includes the stack trace in the response unless `NODE_ENV=production`.

On Express, body-parser failures occur before resAPI processes the request, so Express determines their response format. Examples include a body that exceeds the size limit (413), an unsupported charset (415), and malformed JSON rejected by an upstream `express.json()` parser (400). See [Request bodies](request-bodies.md).

### Content type

A typed POST accepts any content type as long as the body is valid JSON. resAPI itself never returns HTTP 415. See [Request bodies](request-bodies.md).

## On the client

`Client.call` and `Client.callWithBody` return `result<'response, Client.error<'e>>`, where `'e` is the contract's declared error type:

| Variant | When |
| --- | --- |
| `Application({status, error})` | The server sent a declared error that decoded with the contract's error codec |
| `Unauthorized({status, reason})` | A 401 or 403 response that is not a declared application error. `reason` is set when the body is a resAPI `Reject` response with a message |
| `UnexpectedStatus({status, body})` | Any other non-2xx response, including resAPI's 400s and 500s, framework errors, and proxy failures. `body` contains the raw response text |
| `InvalidResponse({path, message})` | The response violates the contract: a 2xx body is invalid JSON or fails the response codec, an `applicationError` fails the error codec, or the endpoint returns an `applicationError` without declaring errors |
| `Network(message)` | The `fetch` call failed, for example because of DNS, a refused connection, or CORS |
| `Aborted` | The call's `~signal` was aborted or timed out |

**Bugs in the calling code reject the promise.** An invalid `baseUrl`, a missing or non-scalar path parameter, or a codec that throws during encoding causes the call to reject with a JavaScript `Error`. In these cases, no request is sent.

### How a failed response is classified

1. A body containing `"applicationError"` is treated as a declared application error, regardless of status, including 401 and 403. If it fails to decode, or the endpoint declares no errors, the result is `InvalidResponse`.
2. Any other 401 or 403 becomes `Unauthorized`. If the body has the rejection format produced by `Reject`, with kind `"unauthenticated"` or `"forbidden"` and a non-empty message, `reason` is `Some(message)`. For plain text, HTML, or other JSON, it is `None`.
3. Any remaining non-2xx response becomes `UnexpectedStatus`.

Handle the errors that need specific behavior, then use `Client.message` as a fallback:

```rescript
switch await client->Client.call(AccountApi.getAccount, ~params={id: id}) {
| Ok(account) => Ok(account)
| Error(Application({error: NotFound})) => Error("No such account.")
| Error(Unauthorized({reason: Some("mfa_required"), _})) => Error("Turn on two-factor authentication first.")
| Error(error) => Error(Client.message(error, ~declared=_ => "That didn't work."))
}
```

## Reading type errors

ReScript reports contract mismatches as type errors. These messages can be long because they include the full types. Look for "This has type … But it's expected to have type …" to compare the value you supplied with the type the contract requires. For long generic types, the final "The incompatible parts" lines isolate the difference. For example, a `getAccount` handler that returns `Ok("a1")` produces:

```text
This has type: string
But it's expected to have type: AccountApi.account
```
