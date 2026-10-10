// Node entry point: `npm start` (API_SECRET and PORT from the environment).
open ResApiExpress

@scope(("process", "env")) @val external portVar: option<string> = "PORT"

let port = portVar->Option.flatMap(p => Int.fromString(p))->Option.getOr(3000)

let server =
  App.app->Router.listen(port, () =>
    Console.log(`Listening on http://localhost:${port->Int.toString}`)
  )
