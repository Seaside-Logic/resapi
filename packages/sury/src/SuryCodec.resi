// Sury schema -> resAPI codec.

/** Compiles both directions immediately: call it at module top level, because Workers forbid the
    `new Function` that Sury uses once a request is running. Errors keep Sury's field path, with array
    indexes as strings. */
let make: S.t<'a> => ResApi.Codec.t<'a>
