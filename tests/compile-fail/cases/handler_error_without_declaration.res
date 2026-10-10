// expect: This has type: TestApi.accountError
// createAccount declares no application errors, so its handler can't return one.
open ResApiHono
let route = TestApi.createAccount->EndpointHandler.make(async (_ctx, _) => Error(TestApi.NotFound))
