// @ts-check

import cloudflare from "@astrojs/cloudflare";
import { satteri } from "@astrojs/markdown-satteri";
import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";
import { agentsSummary } from "@nuasite/agent-summary";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, fontProviders } from "astro/config";
import astroAgentAnnotate from "astro-agent-annotate";
import favicons from "astro-favicons";
import { defineHastPlugin } from "satteri";
import { defineConfig as viteConfig } from "vite";

// Blog posts: links that leave the site open in a new tab. Done at build time
// in the Markdown processor, so no client JS ships for it.
const externalLinks = defineHastPlugin({
	name: "external-links",
	element: {
		filter: ["a"],
		visit(node, ctx) {
			const href = node.properties?.href;
			if (typeof href !== "string" || !/^https?:\/\//.test(href)) return;
			if (href.startsWith("https://gozdar.dz0ny.dev")) return;
			ctx.setProperty(node, "target", "_blank");
			ctx.setProperty(node, "rel", "noopener noreferrer");
		},
	},
});

const isDevelopment = process.env.NODE_ENV === "development";
const devToolbar = { enabled: isDevelopment };

// https://astro.build/config
export default defineConfig({
	site: "https://gozdar.dz0ny.dev",
	output: "static",
	trailingSlash: "always",
	markdown: {
		processor: satteri({ hastPlugins: [externalLinks] }),
	},
	// No `image.service` key on purpose: Astro's schema default is already
	// `astro/assets/services/sharp`, which is what we want. Setting it explicitly
	// buys nothing — and see the adapter note below before changing `imageService`.
	integrations: [
		react(),
		sitemap({ filter: (page) => !page.includes("/branding/") }),
		agentsSummary(),
		...(devToolbar.enabled ? [astroAgentAnnotate()] : []),
		favicons({
			input: "./src/assets/icon.png",
			name: "Gozdar",
			short_name: "Gozdar",
		}),
	],

	vite: viteConfig({
		cacheDir: ".astro/vite",
		plugins: [tailwindcss()],
		resolve: {
			alias: {
				"@": "/src",
			},
		},
	}),

	build: {
		concurrency: 4,
		// Keep this at "auto" (Astro's default: inline only stylesheets under ~4 kB).
		// Forcing "always" puts the whole compiled Tailwind bundle in a <style> block
		// in every document — byte-identical CSS re-transferred on every navigation,
		// and render delay dominates LCP because nothing paints until it is parsed.
		// A bundle over ~15 kB belongs behind the immutable /_astro/* cache instead.
		inlineStylesheets: "auto",
	},

	server: { port: 4321, host: "0.0.0.0", allowedHosts: true },
	devToolbar,
	// `imageService: "custom"` is load-bearing — do NOT "fix" it to "compile".
	// In the adapter's `setImageConfig()`, "compile" returns the workerd image
	// service (v13 does so unconditionally; v14 keeps sharp only if a custom
	// service is set, and `hasUserImageService()` explicitly excludes sharp).
	// "custom" is the only branch that returns the config untouched, so it is
	// what lets Astro's sharp service survive. `prerenderEnvironment: "node"`
	// pairs with it so sharp runs in plain Node during the build, not workerd.
	adapter: isDevelopment
		? undefined
		: cloudflare({ imageService: "custom", prerenderEnvironment: "node" }),

	// Slovenian needs latin-ext (č, š, ž) — without it those glyphs fall back
	// to a system font mid-word.
	fonts: [
		{
			provider: fontProviders.google(),
			name: "Fraunces",
			cssVariable: "--font-fraunces",
			weights: ["400 800"],
			styles: ["normal"],
			subsets: ["latin", "latin-ext"],
			fallbacks: ["Georgia", "serif"],
		},
		{
			provider: fontProviders.google(),
			name: "Instrument Sans",
			cssVariable: "--font-instrument",
			weights: ["400 700"],
			styles: ["normal"],
			subsets: ["latin", "latin-ext"],
			fallbacks: ["ui-sans-serif", "system-ui", "sans-serif"],
		},
	],
});
