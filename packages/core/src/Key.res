// A typed name for a request value: see Key.resi.
type t<'a> = string

let make = name => name

let name = key => key

let orThrow = (value, key) =>
  switch value {
  | Some(value) => value
  | None =>
    JsError.throwWithMessage(`No value for key "${key}": is its middleware mounted for this path?`)
  }
