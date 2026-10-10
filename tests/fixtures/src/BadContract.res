// A mismatched top-level contract: importing this module must throw. Used by tests/route-check.test.mjs.
let getAccount = ResApi.Endpoint.get(
  "/accounts/:accountId",
  ~params=TestApi.paramsCodec,
  ~response=TestApi.accountCodec,
)
