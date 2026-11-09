import rss from "@astrojs/rss";
import type { APIRoute } from "astro";
import { postPath, publishedPosts } from "@/lib/blog";
import { CONTACT_EMAIL, SITE_NAME } from "@/lib/site";

export const GET: APIRoute = async ({ site }) => {
	const posts = await publishedPosts();
	return rss({
		title: `${SITE_NAME} blog`,
		description:
			"Funkcije aplikacije Gozdar, vsaka posebej: kaj naredi in kako jo uporabite na terenu.",
		site: site ?? "https://gozdar.dz0ny.dev",
		trailingSlash: true,
		customData: "<language>sl</language>",
		items: posts.map((post) => ({
			title: post.data.title,
			description: post.data.description,
			pubDate: post.data.date,
			link: postPath(post),
			categories: [post.data.category],
			// RSS 2.0 defines <author> as an e-mail address; the name goes in parentheses.
			author: `${CONTACT_EMAIL} (${post.data.author})`,
		})),
	});
};
