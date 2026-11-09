import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

// Blog: one post per app feature. The post URL is the file name
// (`src/content/blog/<id>.md` → `/blog/<id>/`), so there is no separate slug.
const blog = defineCollection({
	loader: glob({ pattern: "**/*.md", base: "./src/content/blog" }),
	schema: ({ image }) =>
		z.object({
			title: z.string(),
			description: z.string(),
			date: z.coerce.date(),
			updated: z.coerce.date().optional(),
			category: z.string(),
			author: z.string(),
			// A screenshot from src/assets, referenced relative to the post file.
			cover: image().optional(),
			coverAlt: z.string().optional(),
			draft: z.boolean().default(false),
		}),
});

export const collections = { blog };
