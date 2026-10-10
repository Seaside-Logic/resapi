// The shared contract, defined with Sury schemas as the README shows.
open ResApi

@schema
type params = {id: string}

@schema
type account = {id: string, name: string}

@schema
type newAccount = {name: string}

@schema
type accountError = | @as("not_found") NotFound

let accountCodec = SuryCodec.make(accountSchema)

let getAccount = Endpoint.get(
  "/accounts/:id",
  ~params=SuryCodec.make(paramsSchema),
  ~response=accountCodec,
)->Endpoint.withErrors(SuryCodec.make(accountErrorSchema), ~status=error =>
  switch error {
  | NotFound => 404
  }
)

let createAccount = Endpoint.post(
  "/accounts",
  ~params=Codec.unit,
  ~body=SuryCodec.make(newAccountSchema),
  ~response=accountCodec,
)
