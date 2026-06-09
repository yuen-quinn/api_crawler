# Changelog

## 0.1.0

- Initial release
- `CrawlerEngine` with batched discovery and pipeline execution
- Pipeline stages: Fetch, Transform, Dedupe, Persist, Emit
- `ApiAdapter` extension point for any REST/JSON API
- `HttpTransport` with rate limiting and retry policy
- In-memory and file-based record/checkpoint stores
- `CrawlerRegistry` for adapter registration
- Cursor-based pagination helper
