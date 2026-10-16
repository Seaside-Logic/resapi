/** Renders trusted, bundled Markdown (the guides) with highlighted code fences. Links between docs
(`errors.md#on-the-client`) become site routes, other relative links point at the GitHub repo, and
headings get GitHub-style ids so those anchors resolve. Clicks on site links navigate client-side. */

type codeToken = {text: string, lang?: string}
type headingToken = {text: string, depth: int}
type linkToken = {href: string, text: string}
type parser
type renderer = {
  code: codeToken => string,
  heading: headingToken => string,
  link: linkToken => string,
}
type options = {renderer: renderer}
type marked

@module("marked") @new external make: options => marked = "Marked"
@send external parse: (marked, string) => string = "parse"
@module("marked") external parseInline: string => string = "parseInline"

let docsUrl = "https://github.com/Seaside-Logic/resapi/blob/main/site/content/"

type url
@new external makeUrl: (string, string) => url = "URL"
@get external urlHref: url => string = "href"

/** GitHub's heading anchor: lowercase, punctuation dropped, spaces to hyphens. */
let slugify = text =>
  text
  ->String.toLowerCase
  ->String.replaceRegExp(/<[^>]*>/g, "")
  ->String.replaceRegExp(/[^\w\- ]/g, "")
  ->String.replaceAll(" ", "-")

/** Site or GitHub URL for a link written for the site/content/ folder. */
let resolveHref = href =>
  if href->String.startsWith("http") || href->String.startsWith("#") || href->String.startsWith("mailto:") {
    href
  } else {
    switch href->String.match(/^([\w-]+)\.md(#.*)?$/) {
    | Some([_, Some(slug), anchor]) => `/guides/${slug}${anchor->Option.getOr("")}`
    | _ => makeUrl(href, docsUrl)->urlHref
    }
  }

let escapeAttr = s => s->String.replaceAll("&", "&amp;")->String.replaceAll("\"", "&quot;")

let marked = make({
  renderer: {
    code: ({text, ?lang}) => Highlight.toHtml(text, ~lang=lang->Option.getOr("text")),
    heading: ({text, depth}) => {
      let html = parseInline(text)
      `<h${depth->Int.toString} id="${slugify(html)}">${html}</h${depth->Int.toString}>`
    },
    link: ({href, text}) => {
      let href = resolveHref(href)
      let external_ = href->String.startsWith("http")
      let target = external_ ? ` target="_blank" rel="noreferrer"` : ""
      `<a href="${escapeAttr(href)}"${target}>${parseInline(text)}</a>`
    },
  },
})

@get external targetElement: ReactEvent.Mouse.t => Dom.element = "target"
@send @return(nullable) external closest: (Dom.element, string) => option<Dom.element> = "closest"
@send external getAttribute: (Dom.element, string) => string = "getAttribute"

let onClick = event => {
  open ReactEvent.Mouse
  let modified = metaKey(event) || ctrlKey(event) || shiftKey(event) || altKey(event)
  switch event->targetElement->closest("a[href^='/']") {
  | Some(link) if !modified =>
    preventDefault(event)
    RescriptReactRouter.push(link->getAttribute("href"))
  | _ => ()
  }
}

@react.component
let make = (~source) => {
  let html = React.useMemo1(() => marked->parse(source), [source])
  <div className="prose" onClick dangerouslySetInnerHTML={{"__html": html}} />
}
