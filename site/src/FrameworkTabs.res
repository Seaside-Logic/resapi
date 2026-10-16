/** Hono and Express versions of a sample, one tab each. Controlled, so every block on a page
follows the same choice. Pass the same element as both for samples that don't differ. */

module Logo = {
  @react.component
  let make = (~framework: Framework.t) =>
    switch framework {
    | Hono => <Icon.Hono />
    | Express => <Icon.Express />
    }
}

@react.component
let make = (~value, ~onChange, ~hono, ~express) =>
  <Radix.Tabs.Root
    className="framework-tabs"
    value={Framework.toString(value)}
    onValueChange={value => Framework.fromString(value)->Option.forEach(onChange)}>
    <Radix.Tabs.List className="framework-tabs-list" ariaLabel="Server framework">
      {Framework.all
      ->Array.map(framework =>
        <Radix.Tabs.Trigger
          key={Framework.toString(framework)}
          className="framework-tabs-trigger"
          value={Framework.toString(framework)}>
          <Logo framework />
          {React.string(Framework.label(framework))}
        </Radix.Tabs.Trigger>
      )
      ->React.array}
    </Radix.Tabs.List>
    <Radix.Tabs.Content className="framework-tabs-content" value={Framework.toString(Hono)}> hono </Radix.Tabs.Content>
    <Radix.Tabs.Content className="framework-tabs-content" value={Framework.toString(Express)}> express </Radix.Tabs.Content>
  </Radix.Tabs.Root>
