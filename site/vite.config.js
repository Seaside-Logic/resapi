import { defineConfig, runnerImport } from 'vite'

// Serves (dev) and emits (build) the Markdown files built by src/LlmsTxt.res for AI agents.
const llmsTxt = () => {
  const load = async () =>
    new Map((await runnerImport('/src/LlmsTxt.res.mjs', { configFile: false })).module.files)
  return {
    name: 'llms-txt',
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        if (!/\.(md|txt)$/.test(req.url)) return next()
        const body = (await load()).get(req.url)
        if (body === undefined) return next()
        res.setHeader('Content-Type', 'text/markdown; charset=utf-8')
        res.end(body)
      })
    },
    async generateBundle() {
      for (const [path, source] of await load())
        this.emitFile({ type: 'asset', fileName: path.slice(1), source })
    },
  }
}

export default defineConfig({
  plugins: [llmsTxt()],
  resolve: {
    // The bindings compile into ../src and would otherwise resolve these from ../node_modules,
    // giving the page two copies of React.
    dedupe: ['react', 'react-dom', 'radix-ui'],
  },
  server: { fs: { allow: ['..'] } },
  build: {
    rolldownOptions: {
      // Radix modules start with "use client", which only matters to server-component bundlers.
      onwarn(warning, warn) {
        if (warning.code !== 'MODULE_LEVEL_DIRECTIVE') warn(warning)
      },
    },
  },
})
