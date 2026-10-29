// Samples are copied from the root README, whose examples `npm run check:packages` compiles. Keep them in step.

let installHono = "npm install @resapi/core @resapi/hono @resapi/sury hono sury sury-ppx"
let installExpress = "npm install @resapi/core @resapi/express @resapi/sury express sury sury-ppx"

let contract = `
open ResApi

@schema type params = {id: string}
@schema type account = {id: string, name: string, balance: float}
@schema type accountError = | @as("not_found") NotFound

let getAccount =
  Endpoint.get(
    "/accounts/:id",
    ~params=SuryCodec.make(paramsSchema),
    ~response=SuryCodec.make(accountSchema),
  )->Endpoint.withErrors(SuryCodec.make(accountErrorSchema), ~status=error =>
    switch error {
    | NotFound => 404
    }
  )
`

let honoApp = `
open ResApiHono

let app: Router.t<unit> =
  Router.make()
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      switch accounts->Dict.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )

// A router is a Hono app, so it is already a Cloudflare Worker.
let default = app
`

let expressApp = `
open ResApiExpress

let app =
  Router.make()
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_req, {params}) =>
      switch accounts->Dict.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )
`

let expressServer = `
// A router is an Express app, so Express middleware works as is.
let server = ExpressApp.app->ResApiExpress.Router.listen(3000, () => Console.log("Listening on :3000"))
`

let clientCall = `
switch await client->Client.call(AccountApi.getAccount, ~params={id: id}) {
| Ok(account) => account.name
| Error(Application({error: NotFound})) => "no such account"
| Error(_) => "request failed"
}
`

type feature = {title: string, text: string}

let features = [
  {
    title: "One definition",
    text: "Server handlers and client calls take their types from the same contract value, with no generated code.",
  },
  {
    title: "Validated at both ends",
    text: "Requests are decoded before your handler runs. Responses are decoded before your code sees them.",
  },
  {
    title: "Typed application errors",
    text: "Each endpoint lists the errors it can return, such as NotFound or AccessDenied, and their HTTP statuses. Clients handle them separately from network and validation failures.",
  },
  {
    title: "Native frameworks",
    text: "A router is a Hono or Express app, so their middleware works as is.",
  },
]

type package = {name: string, text: string}

let packages = [
  {name: "@resapi/core", text: "Contracts, codecs and the typed client. Depends only on Fetch."},
  {name: "@resapi/hono", text: "Hono 4 adapter, tested on Cloudflare Workers."},
  {name: "@resapi/express", text: "Express 5 adapter."},
  {name: "@resapi/sury", text: "Sury schemas as codecs. Hand-written codecs work too."},
]

module Card = {
  @react.component
  let make = (~route, ~title, ~children) =>
    <Route.Link route className="card">
      <h3 className="card-title"> {React.string(title)} </h3>
      <p className="card-text"> {React.string(children)} </p>
      <span className="card-more">
        {React.string("Read more")}
        <Icon.ArrowRight />
      </span>
    </Route.Link>
}

module Step = {
  @react.component
  let make = (~title, ~text, ~children) =>
    <section className="section">
      <h2> {React.string(title)} </h2>
      <p> {React.string(text)} </p>
      children
    </section>
}

@react.component
let make = () => {
  let (framework, setFramework) = Framework.useFramework()
  let tabs = (~hono, ~express) =>
    <FrameworkTabs value=framework onChange=setFramework hono express />
  let same = element => tabs(~hono=element, ~express=element)

  <>
    <title> {React.string("resAPI: type-safe HTTP contracts for ReScript")} </title>
    <section className="hero">
      <h1> {React.string("Type-safe HTTP contracts for ReScript")} </h1>
      <p className="lead">
        {React.string(
          "Define your API once. Share types and validation between clients and servers, on Hono, Express or Cloudflare Workers.",
        )}
      </p>
      <div className="hero-actions">
        <Route.Link route=Guide("getting-started") className="button primary pill">
          {React.string("Get started")}
          <Icon.ArrowRight />
        </Route.Link>
        <Route.Link route=Guide("api") className="button pill">
          {React.string("API reference")}
        </Route.Link>
      </div>
      {tabs(~hono=<Code lang="sh" code=installHono />, ~express=<Code lang="sh" code=installExpress />)}
    </section>
    <Step
      title="1. Describe the endpoint"
      text="A contract names the route, the params, the response and the errors the endpoint can return. Clients and servers both import it.">
      {same(<Code file="AccountApi.res" code=contract />)}
    </Step>
    <Step
      title="2. Implement it"
      text="The handler receives decoded, validated params. Values returned from the handler must conform to the API contract or the compiler will raise an error.">
      {tabs(
        ~hono=<Code file="App.res" code=honoApp />,
        ~express=<>
          <Code file="ExpressApp.res" code=expressApp />
          <Code file="Server.res" code=expressServer />
        </>,
      )}
    </Step>
    <Step
      title="3. Call it"
      text="The client builds the URL, validates the response, and returns a strongly typed result.">
      {same(<Code file="AccountClient.res" code=clientCall />)}
    </Step>
    <section className="section">
      <h2 className="section-heading"> {React.string("Why resAPI")} </h2>
      <div className="cards features">
        {features
        ->Array.map(feature =>
          <div key=feature.title className="card static">
            <h3 className="card-title"> {React.string(feature.title)} </h3>
            <p className="card-text"> {React.string(feature.text)} </p>
          </div>
        )
        ->React.array}
      </div>
    </section>
    <section className="section">
      <h2 className="section-heading"> {React.string("Guides")} </h2>
      <div className="cards">
        {Guides.all
        ->Array.map(guide =>
          <Card key=guide.slug route=Guide(guide.slug) title=guide.title> {guide.summary} </Card>
        )
        ->React.array}
      </div>
    </section>
    <section className="section">
      <h2 className="section-heading"> {React.string("Packages")} </h2>
      <div className="prose">
        <table>
          <tbody>
            {packages
            ->Array.map(package =>
              <tr key=package.name>
                <td>
                  <a
                    href={`https://www.npmjs.com/package/${package.name}`}
                    target="_blank"
                    rel="noreferrer">
                    <code> {React.string(package.name)} </code>
                  </a>
                </td>
                <td> {React.string(package.text)} </td>
              </tr>
            )
            ->React.array}
          </tbody>
        </table>
      </div>
      <p className="note">
        {React.string("0.3.0 is a preview: the API may change in 0.x releases. See the ")}
        <a
          href="https://github.com/Seaside-Logic/resapi/blob/main/CHANGELOG.md"
          target="_blank"
          rel="noreferrer">
          {React.string("changelog")}
        </a>
        {React.string(" for tested versions and known limitations.")}
      </p>
    </section>
  </>
}
