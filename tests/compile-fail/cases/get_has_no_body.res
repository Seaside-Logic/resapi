// expect: unit vs CaseApi.newAccount
// A GET contract's body type is fixed to unit.
open ResApi
let contract: Endpoint.t<_, CaseApi.newAccount, _> = Endpoint.get(
  "/accounts/:id",
  ~params=CaseApi.paramsCodec,
  ~response=CaseApi.accountCodec,
)
