// expect: But it's expected to have type: TestApi.accountError
// getAccount declares accountError; a handler can't return some other error type.
open ResApiHono
let route = TestApi.getAccount->EndpointHandler.make(async (_ctx, _) => Error("not found"))
