/**
 * Cloudflare Edge Cache Middleware for Hono
 * Disabled in development mode (localhost)
 */
export const cache = () => {
  return async (c, next) => {
    // Skip caching in development mode
    const url = new URL(c.req.url);
    const isDev = url.hostname === 'localhost' || url.hostname === '127.0.0.1';

    if (isDev) {
      console.log(`[DEV] Cache disabled for ${c.req.url}`);
      return next();
    }

    const cache = caches.default;

    // Create versioned cache key
    const cacheUrl = new URL(c.req.url);
    cacheUrl.searchParams.set('_v', 'v2');
    const cacheKey = new Request(cacheUrl.toString(), c.req.raw);

    // Try cache first
    let response = await cache.match(cacheKey);

    if (response) {
      console.log(`Cache hit for ${c.req.url}`);
      return response;
    }

    // Call next handler
    await next();

    // Cache successful responses
    if (c.res && c.res.ok && c.res.status < 400) {
      c.executionCtx.waitUntil(cache.put(cacheKey, c.res.clone()));
    }
  };
};
