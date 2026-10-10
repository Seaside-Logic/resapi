// expect: But it's expected to have type: TestApi.accountError
// The Express adapter reads handler types off the contract too: getAccount declares accountError only.
open ResApiExpress
let route = TestApi.getAccount->EndpointHandler.make(async (_req, _) => Error("not found"))
