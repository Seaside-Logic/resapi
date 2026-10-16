@react.component
let make = () =>
  <Route.Link route=Home className="brand">
    <Icon.Logo />
    <span>
      {React.string("res")}
      <span className="brand-accent"> {React.string("API")} </span>
    </span>
  </Route.Link>
