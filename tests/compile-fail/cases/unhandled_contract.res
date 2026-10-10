// expect: ResApiHono.EndpointHandler.route<'a>
// A bare contract has no handler and cannot be registered.
open ResApiHono
let app: Router.t<unit> = Router.make()->Router.register(TestApi.getAccount)
