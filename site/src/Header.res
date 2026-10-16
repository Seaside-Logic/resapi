/** The top bar. On narrow screens it also holds the brand and a menu button that opens the
navigation in a Radix dialog. */

module ThemeToggle = {
  @react.component
  let make = () => {
    let (theme, toggle) = Theme.useTheme()
    let label = switch theme {
    | Light => "Switch to dark theme"
    | Dark => "Switch to light theme"
    }

    <Radix.Tooltip.Root>
      <Radix.Tooltip.Trigger asChild=true>
        <button className="icon-button" ariaLabel=label onClick={_ => toggle()}>
          {switch theme {
          | Light => <Icon.Moon />
          | Dark => <Icon.Sun />
          }}
        </button>
      </Radix.Tooltip.Trigger>
      <Radix.Tooltip.Portal>
        <Radix.Tooltip.Content className="tooltip" sideOffset=6>
          {React.string(label)}
          <Radix.Tooltip.Arrow className="tooltip-arrow" />
        </Radix.Tooltip.Content>
      </Radix.Tooltip.Portal>
    </Radix.Tooltip.Root>
  }
}

module MobileNav = {
  @react.component
  let make = (~route) => {
    let (open_, setOpen) = React.useState(() => false)

    // Close after navigating. The href is a stable dependency; the route variant is a new object each render.
    let href = Route.toHref(route)
    React.useEffect1(() => {
      setOpen(_ => false)
      None
    }, [href])

    <Radix.Dialog.Root open_ onOpenChange={value => setOpen(_ => value)}>
      <Radix.Dialog.Trigger asChild=true>
        <button className="icon-button menu-button" ariaLabel="Open navigation"> <Icon.Menu /> </button>
      </Radix.Dialog.Trigger>
      <Radix.Dialog.Portal>
        <Radix.Dialog.Overlay className="overlay" />
        <Radix.Dialog.Content className="mobile-nav">
          <Radix.VisuallyHidden.Root>
            <Radix.Dialog.Title> {React.string("Navigation")} </Radix.Dialog.Title>
          </Radix.VisuallyHidden.Root>
          <div className="mobile-nav-header">
            <Brand />
            <Radix.Dialog.Close asChild=true>
              <button className="icon-button" ariaLabel="Close navigation"> <Icon.Close /> </button>
            </Radix.Dialog.Close>
          </div>
          <Sidebar current=route />
        </Radix.Dialog.Content>
      </Radix.Dialog.Portal>
    </Radix.Dialog.Root>
  }
}

@react.component
let make = (~route) =>
  <header className="header">
    <MobileNav route />
    <div className="header-brand"> <Brand /> </div>
    <nav className="header-links" ariaLabel="Main">
      <Route.Link route=Guide("getting-started")> {React.string("Guides")} </Route.Link>
      <Route.Link route=Guide("api")> {React.string("API reference")} </Route.Link>
      <a href="https://www.npmjs.com/package/@resapi/core" target="_blank" rel="noreferrer">
        {React.string("npm")}
        <Icon.External />
      </a>
    </nav>
    <div className="header-divider" />
    <a
      className="icon-button"
      href="https://github.com/Seaside-Logic/resapi"
      target="_blank"
      rel="noreferrer">
      <Icon.GitHub />
    </a>
    <ThemeToggle />
    <Route.Link route=Guide("getting-started") className="button primary pill header-cta">
      {React.string("Get started")}
    </Route.Link>
  </header>
