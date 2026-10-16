@react.component
let make = (~guide: Guides.t) => {
  let index = Guides.all->Array.findIndex(g => g.slug == guide.slug)
  let next = Guides.all->Array.get(index + 1)
  let hasFrameworks = Guides.hasFrameworks(guide)
  let (framework, setFramework) = Framework.useFramework()

  // styles.css hides the sections of the framework that isn't shown.
  <article className={hasFrameworks ? `page show-${Framework.toString(framework)}` : "page"}>
    <title> {React.string(`${guide.title} · resAPI`)} </title>
    <p className="eyebrow">
      {React.string(
        switch guide.section {
        | Guides => "Guide"
        | Reference => "Reference"
        },
      )}
    </p>
    <h1> {React.string(guide.title)} </h1>
    <p className="lead"> {React.string(guide.summary)} </p>
    {hasFrameworks ? <FrameworkToggle value=framework onChange=setFramework /> : React.null}
    <Markdown source=guide.body />
    {switch next {
    | Some(next) =>
      <Route.Link route=Guide(next.slug) className="pager">
        <span className="muted"> {React.string("Next")} </span>
        <span className="pager-title">
          {React.string(next.title)}
          <Icon.ArrowRight />
        </span>
      </Route.Link>
    | None => React.null
    }}
  </article>
}
