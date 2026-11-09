import { type CollectionEntry, getCollection } from "astro:content";
import type { ImageMetadata } from "astro";

export type Post = CollectionEntry<"blog">;

/** Published posts, newest first. Drafts are left out of every route and the feed. */
export async function publishedPosts(): Promise<Post[]> {
	const posts = await getCollection("blog", ({ data }) => !data.draft);
	return posts.sort((a, b) => b.data.date.valueOf() - a.data.date.valueOf());
}

export function postPath(post: Post): string {
	return `/blog/${post.id}/`;
}

const dateFormat = new Intl.DateTimeFormat("sl-SI", {
	day: "numeric",
	month: "long",
	year: "numeric",
});

export function formatDate(date: Date): string {
	return dateFormat.format(date);
}

/**
 * The post's cover as `ImageMetadata`. The `image()` schema helper types
 * `format` as optional while `<Picture>` requires it; the value at runtime is
 * the full metadata object, so the cast is only a type-level reconciliation.
 */
export function coverOf(post: Post): ImageMetadata | undefined {
	return post.data.cover as ImageMetadata | undefined;
}
