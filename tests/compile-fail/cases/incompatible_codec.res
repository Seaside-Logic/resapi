// expect: TestApi.params vs TestApi.account
// The params codec passed as the response codec doesn't fit a contract that promises an account.
open ResApi
let contract: Endpoint.t<TestApi.params, unit, TestApi.account, _> = Endpoint.get(
  "/accounts/:id",
  ~params=TestApi.paramsCodec,
  ~response=TestApi.paramsCodec,
)
