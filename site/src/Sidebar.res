/** Site navigation: guides and reference. Shared by the desktop sidebar and the mobile menu. */

module Item = {
  @react.component
  let make = (~route, ~current, ~children) => {
    let isCurrent = Route.toHref(route) == Route.toHref(current)
    <li>
      <Route.Link route className="sidebar-link" ariaCurrent=?{isCurrent ? Some(#page) : None}>
        {React.string(children)}
      </Route.Link>
    </li>
  }
}

module Section = {
  @react.component
  let make = (~title, ~children) =>
    <section className="sidebar-section">
      <h2 className="sidebar-heading"> {React.string(title)} </h2>
      <ul className="sidebar-list"> children </ul>
    </section>
}

let guides = (section, ~current) =>
  Guides.inSection(section)
  ->Array.map(guide => <Item key=guide.slug route=Guide(guide.slug) current> {guide.title} </Item>)
  ->React.array

@react.component
let make = (~current) =>
  <nav className="sidebar-nav" ariaLabel="Documentation">
    <Section title="Guides">
      <Item route=Home current> {"Introduction"} </Item>
      {guides(Guides, ~current)}
    </Section>
    <Section title="Reference"> {guides(Reference, ~current)} </Section>
  </nav>
