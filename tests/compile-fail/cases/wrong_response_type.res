// expect: But it's expected to have type: TestApi.account
// Handler returns a string where the contract promises an account.
open ResApiHono
let route = TestApi.getAccount->EndpointHandler.make(async (_ctx, _) => Ok("a1"))
