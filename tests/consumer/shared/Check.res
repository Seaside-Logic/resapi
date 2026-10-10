// Assertions for the consumer projects: a failed check throws, and the unhandled rejection fails the run.
let check = (cond, message) =>
  if !cond {
    JsError.throwWithMessage(`check failed: ${message}`)
  }
