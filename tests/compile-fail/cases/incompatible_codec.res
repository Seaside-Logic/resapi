// expect: CaseApi.params vs CaseApi.account
// The params codec passed as the response codec doesn't fit a contract that promises an account.
open ResApi
let contract: Endpoint.t<CaseApi.params, unit, CaseApi.account> = Endpoint.get(
  "/accounts/:id",
  ~params=CaseApi.paramsCodec,
  ~response=CaseApi.paramsCodec,
)
