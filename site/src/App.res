@val @scope("window") external scrollTo: (int, int) => unit = "scrollTo"
@val @scope("document") @return(nullable)
external getElementById: string => option<Dom.element> = "getElementById"
@send external scrollIntoView: Dom.element => unit = "scrollIntoView"

module NotFound = {
  @react.component
  let make = () =>
    <article className="page">
      <title> {React.string("Not found · resAPI")} </title>
      <h1> {React.string("Page not found")} </h1>
      <p className="lead">
        <Route.Link route=Home> {React.string("Back to the introduction")} </Route.Link>
      </p>
    </article>
}

@react.component
let make = () => {
  let url = RescriptReactRouter.useUrl()
  let route = Route.fromUrl(url)

  // New page: go to the linked heading if there is one, otherwise the top.
  React.useEffect1(() => {
    switch url.hash == "" ? None : getElementById(url.hash) {
    | Some(heading) => heading->scrollIntoView
    | None => scrollTo(0, 0)
    }
    None
  }, [url])

  let page = switch route {
  | Home => <HomePage />
  | Guide(slug) =>
    switch Guides.find(slug) {
    | Some(guide) => <GuidePage key=slug guide />
    | None => <NotFound />
    }
  | NotFound => <NotFound />
  }

  <Radix.Tooltip.Provider>
    <div className="layout">
      <aside className="sidebar">
        <Brand />
        <Sidebar current=route />
      </aside>
      <div className="main">
        <Header route />
        <main className="content"> page </main>
        <footer className="footer">
          {React.string("MIT licensed · © Seaside Logic")}
        </footer>
      </div>
    </div>
  </Radix.Tooltip.Provider>
}
