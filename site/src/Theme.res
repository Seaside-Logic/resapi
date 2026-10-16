/** Light/dark theme. index.html sets `data-theme` before first paint; this hook reads and updates it. */

type t =
  | @as("light") Light
  | @as("dark") Dark

type dataset
@val @scope(("document", "documentElement")) external dataset: dataset = "dataset"
@get external get: dataset => t = "theme"
@set external set: (dataset, t) => unit = "theme"
@val @scope("localStorage") external persist: (@as("theme") _, t) => unit = "setItem"

let useTheme = () => {
  let (theme, setTheme) = React.useState(() => dataset->get)

  let toggle = () => {
    let next = theme == Light ? Dark : Light
    dataset->set(next)
    // Storage can be unavailable (private mode, blocked site data); the toggle still works for this visit.
    try persist(next) catch {
    | _ => ()
    }
    setTheme(_ => next)
  }

  (theme, toggle)
}
