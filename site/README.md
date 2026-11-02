# Gozdar website

Landing page, privacy policy (`/zasebnost/`) and support page (`/podpora/`) for https://gozdar.dz0ny.dev.
Astro 6 + Tailwind v4, scaffolded with Hakuto. Design decisions: `site-specification.md`.

```sh
bun install
bun run dev      # http://localhost:4321
bun run build    # writes dist/client
bun run check
```

## Deploy

There is no separate Worker for the site. The existing `../worker` Worker (`gozdar-proxy`) serves
`site/dist/client` through Workers Static Assets, and every path without a matching file (`/tiles/*`,
`/api/*`, `/layers`) still goes to the proxy code in `worker/src/index.js`.

```sh
cd site && bun install && bun run build
cd ../worker && npx wrangler deploy --dry-run   # check
cd ../worker && npx wrangler deploy
```

Local end-to-end check (site + proxy on one origin): build the site, then `cd ../worker && npx wrangler dev`.
