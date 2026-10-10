// Node entry point: `npm start`, which loads .env (copy .env.example). PORT and API_SECRET come from there.
open ResApiExpress

@scope(("process", "env")) @val external portVar: option<string> = "PORT"

let port = switch portVar->Option.flatMap(p => Int.fromString(p)) {
| Some(port) => port
| None => JsError.throwWithMessage("PORT must be set to a port number (see .env.example)")
}

let server =
  App.app->Router.listen(port, () =>
    Console.log(`Listening on http://localhost:${port->Int.toString}`)
  )
