/** A page-wide Hono/Express switch, for guides whose Markdown has a section per framework. It is a
toggle group, not tabs, because the sections it shows and hides are spread through the page. */

@react.component
let make = (~value, ~onChange) =>
  <div className="framework-bar">
    <span className="framework-bar-label"> {React.string("Server")} </span>
    <Radix.ToggleGroup.Single
      type_=#single
      className="framework-tabs-list"
      ariaLabel="Server framework"
      value={Framework.toString(value)}
      onValueChange={value => Framework.fromString(value)->Option.forEach(onChange)}>
      {Framework.all
      ->Array.map(framework =>
        <Radix.ToggleGroup.Item
          key={Framework.toString(framework)}
          className="framework-tabs-trigger"
          value={Framework.toString(framework)}>
          <FrameworkTabs.Logo framework />
          {React.string(Framework.label(framework))}
        </Radix.ToggleGroup.Item>
      )
      ->React.array}
    </Radix.ToggleGroup.Single>
  </div>
