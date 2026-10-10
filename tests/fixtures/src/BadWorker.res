// A Worker whose contracts module has a route mismatch: it must fail to start under workerd.
let contract = BadContract.getAccount
let default: ResApiHono.Router.t<unit> = ResApiHono.Router.make()
