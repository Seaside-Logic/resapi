/** Syntax highlighting with Shiki. The highlighter loads once at startup (top-level await),
so `toHtml` is synchronous everywhere else. Colours come from CSS variables (styles.css maps
them to the site palette), so one render serves both themes. */

type highlighter
type grammar
type theme
type engine

@module("shiki/core") external createHighlighterCore: {..} => promise<highlighter> = "createHighlighterCore"
@module("shiki/core") external createCssVariablesTheme: {..} => theme = "createCssVariablesTheme"
@module("shiki/engine/javascript") external createEngine: unit => engine = "createJavaScriptRegexEngine"

// Shiki ships no ReScript grammar; this one is vendored from rescript-lang/rescript-vscode (MIT).
@module("./rescript.tmLanguage.json") external rescript: grammar = "default"
@module("shiki/langs/json.mjs") external json: grammar = "default"
@module("shiki/langs/shellscript.mjs") external shell: grammar = "default"

let theme = createCssVariablesTheme({"name": "site", "variablePrefix": "--shiki-"})

let highlighter = await createHighlighterCore({
  "langs": [rescript, json, shell],
  "themes": [theme],
  "langAlias": {"rescript": "ReScript", "res": "ReScript"},
  "engine": createEngine(),
})

@send external codeToHtml: (highlighter, string, {..}) => string = "codeToHtml"
@send external getLoadedLanguages: highlighter => array<string> = "getLoadedLanguages"

let loaded = highlighter->getLoadedLanguages

/** Highlighted HTML for `code`. */
let toHtml = (code, ~lang) =>
  highlighter->codeToHtml(code, {"lang": loaded->Array.includes(lang) ? lang : "text", "theme": "site"})
