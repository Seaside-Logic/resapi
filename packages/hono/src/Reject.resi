// Auth rejections for middleware, in resAPI's error shape, so the typed client sees them as
// `Unauthorized({status, reason})`. Return one from middleware: `Some(Reject.unauthenticated())`.

/** 401 `{"error": {"kind": "unauthenticated", "message": <reason or "">, "path": []}}`. */
let unauthenticated: (~reason: string=?) => ResApi.Fetch.Response.t

/** 403 `{"error": {"kind": "forbidden", "message": <reason or "">, "path": []}}`. */
let forbidden: (~reason: string=?) => ResApi.Fetch.Response.t
