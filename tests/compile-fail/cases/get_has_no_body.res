// expect: unit vs TestApi.newAccount
// A GET contract's body type is fixed to unit.
open ResApi
let contract: Endpoint.t<_, TestApi.newAccount, _, _> = Endpoint.get(
  "/accounts/:id",
  ~params=TestApi.paramsCodec,
  ~response=TestApi.accountCodec,
)
