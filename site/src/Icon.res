/** Icons from Lucide (https://lucide.dev), drawn with `currentColor`; GitHub, Logo, Hono and Express are
    hand-drawn since Lucide has no brand icons. Icons that carry meaning on their own announce a fixed label
    via AccessibleIcon; the rest are decorative. */

module Labeled = {
  @react.component
  let make = (~children, ~label=?) =>
    switch label {
    | Some(label) => <Radix.AccessibleIcon.Root label> children </Radix.AccessibleIcon.Root>
    | None => children
    }
}

type lucideProps = {size?: int, fill?: string}
type lucide = React.component<lucideProps>

@module("lucide-react") external check: lucide = "Check"
@module("lucide-react") external arrowRight: lucide = "ArrowRight"
@module("lucide-react") external externalLink: lucide = "ExternalLink"
@module("lucide-react") external x: lucide = "X"
@module("lucide-react") external menu: lucide = "Menu"
@module("lucide-react") external sun: lucide = "Sun"
@module("lucide-react") external moon: lucide = "Moon"
@module("lucide-react") external copy: lucide = "Copy"

module Lucide = {
  @react.component
  let make = (~icon: lucide, ~size=15, ~fill="none", ~label=?) =>
    <Labeled ?label> {React.createElement(icon, ({size, fill}: lucideProps))} </Labeled>
}

module Check = {
  @react.component
  let make = () => <Lucide icon=check />
}

module ArrowRight = {
  @react.component
  let make = () => <Lucide icon=arrowRight />
}

module External = {
  @react.component
  let make = () => <Lucide icon=externalLink label="(opens in a new tab)" />
}

module Close = {
  @react.component
  let make = () => <Lucide icon=x label="Close" />
}

module Menu = {
  @react.component
  let make = () => <Lucide icon=menu label="Menu" size=18 />
}

module Sun = {
  @react.component
  let make = () => <Lucide icon=sun label="Light theme" size=17 />
}

module Moon = {
  @react.component
  let make = () => <Lucide icon=moon label="Dark theme" size=17 />
}

module Copy = {
  @react.component
  let make = () => <Lucide icon=copy label="Copy" />
}

module GitHub = {
  @react.component
  let make = () =>
    <Labeled label="GitHub repository">
      <svg width="17" height="17" viewBox="0 0 16 16" fill="currentColor" ariaHidden=true>
        <path
          d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"
        />
      </svg>
    </Labeled>
}

/** The favicon's mark: an R on an accent tile. */
module Logo = {
  @react.component
  let make = () =>
    <svg width="22" height="22" viewBox="0 0 32 32" ariaHidden=true>
      <rect width="32" height="32" rx="7" fill="var(--accent)" />
      <path d="M9 9h8a5 5 0 0 1 0 10h-2l5 5h-4l-5-5v5H9z" fill="var(--on-accent)" />
    </svg>
}

module Hono = {
  @react.component
  let make = () =>
    <svg width="16" height="16" viewBox="0 0 24 24" ariaHidden=true>
      <path
        fill="#e36002"
        d="M12.445.002a45.529 45.529 0 0 0-5.252 8.146 8.595 8.595 0 0 1-.555-.53 27.796 27.796 0 0 0-1.205-1.542 8.762 8.762 0 0 0-1.251 2.12 20.743 20.743 0 0 0-1.448 5.88 8.867 8.867 0 0 0 .338 3.468c1.312 3.48 3.794 5.593 7.445 6.337 3.055.438 5.755-.333 8.097-2.312 2.677-2.59 3.359-5.634 2.047-9.132a33.287 33.287 0 0 0-2.988-5.59A91.34 91.34 0 0 0 12.615.053a.216.216 0 0 0-.17-.051Zm-.336 3.906a50.93 50.93 0 0 1 4.794 6.552c.448.767.817 1.57 1.108 2.41.606 2.386-.044 4.354-1.951 5.904-1.845 1.298-3.87 1.683-6.072 1.156-2.376-.737-3.75-2.335-4.121-4.794a5.107 5.107 0 0 1 .242-2.266c.358-.908.79-1.774 1.3-2.601l1.446-2.121a397.33 397.33 0 0 0 3.254-4.24Z"
      />
    </svg>
}

module Express = {
  @react.component
  let make = () =>
    <svg width="16" height="16" viewBox="0 0 24 24" ariaHidden=true>
      <path
        fill="currentColor"
        d="M24 18.588a1.529 1.529 0 01-1.895-.72l-3.45-4.771-.5-.667-4.003 5.444a1.466 1.466 0 01-1.802.708l5.158-6.92-4.798-6.251a1.595 1.595 0 011.9.666l3.576 4.83 3.596-4.81a1.435 1.435 0 011.788-.668L21.708 7.9l-2.522 3.283a.666.666 0 000 .994l4.804 6.412zM.002 11.576l.42-2.075c1.154-4.103 5.858-5.81 9.094-3.27 1.895 1.489 2.368 3.597 2.275 5.973H1.116C.943 16.447 4.005 19.009 7.92 17.7a4.078 4.078 0 002.582-2.876c.207-.666.548-.78 1.174-.588a5.417 5.417 0 01-2.589 3.957 6.272 6.272 0 01-7.306-.933 6.575 6.575 0 01-1.64-3.858c0-.235-.08-.455-.134-.666A88.33 88.33 0 010 11.577zm1.127-.286h9.654c-.06-3.076-2.001-5.258-4.59-5.278-2.882-.04-4.944 2.094-5.071 5.264z"
      />
    </svg>
}
