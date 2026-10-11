// Proves the workerd run can catch what Node can't: building a Sury codec during a request needs
// `new Function`, which Workers forbid after module load. Expected: 500 under workerd, 200 under Node.
open ResApi
open ResApiHono

let default: Router.t<unit> = Router.make()->Router.get("/lazy-codec", async _ctx => {
  let codec = SuryCodec.make(S.string)
  Fetch.Response.jsonR(~data=codec.encode("ok"))
})
