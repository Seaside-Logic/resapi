// Bearer auth as native Express middleware. Express has no built-in, so it is written out. The token is
// read from API_SECRET on each request, so a missing secret rejects every request instead of crashing.
open ResApiExpress

@scope(("process", "env")) @val external apiSecret: option<string> = "API_SECRET"

let bearer: Router.middleware = (req, res, next) =>
  switch (apiSecret, req->Req.header("authorization")) {
  | (Some(secret), Some(header)) if header == `Bearer ${secret}` => next()
  | _ => res->Res.status(401)->Res.send("Unauthorized")
  }
