// Checks at contract construction that a route's `:params` and its params codec agree.

/** `CannotValidate`: the codec rejected the probe value at a real route param, e.g. because it refines
    strings. Inconclusive, not a mismatch. */
type outcome = Valid | Invalid(string) | CannotValidate(string)

let check: (string, Codec.t<'p>) => outcome

/** Throws on Invalid, so a bad top-level contract stops the module (and the Worker) from loading. */
let assertValid: (string, Codec.t<'p>) => unit
