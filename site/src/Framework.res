/** The server framework the home page's samples show. The choice is remembered across visits. */

type t =
  | @as("hono") Hono
  | @as("express") Express

let all = [Hono, Express]

let label = framework =>
  switch framework {
  | Hono => "Hono"
  | Express => "Express"
  }

let toString = (framework: t) => (framework :> string)

let fromString = value => all->Array.find(framework => toString(framework) == value)

@val @scope("localStorage") external stored: (@as("framework") _) => Nullable.t<string> = "getItem"
@val @scope("localStorage") external persist: (@as("framework") _, t) => unit = "setItem"

// Storage can be unavailable (private mode, blocked site data); the choice then lasts for this visit.
let load = () =>
  try stored()->Nullable.toOption->Option.flatMap(fromString)->Option.getOr(Hono) catch {
  | _ => Hono
  }

let useFramework = () => {
  let (framework, setFramework) = React.useState(load)

  let select = next => {
    try persist(next) catch {
    | _ => ()
    }
    setFramework(_ => next)
  }

  (framework, select)
}
