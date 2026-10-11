// Auth rejections for middleware, in resAPI's error shape, so the typed client sees them as
// `Unauthorized({status, reason})`. Call one instead of `next()`: `Reject.unauthenticated(res)`.

/** Sends 401 `{"error": {"kind": "unauthenticated", "message": <reason or "">, "path": []}}`. */
let unauthenticated: (Res.t, ~reason: string=?) => unit

/** Sends 403 `{"error": {"kind": "forbidden", "message": <reason or "">, "path": []}}`. */
let forbidden: (Res.t, ~reason: string=?) => unit
