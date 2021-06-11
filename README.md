# laravel-docker

Laravel PHP docker images

# Multiple architecture support

The following builds images for ARM64 and AMD64 to support traditional Intel AMD64 architectures and newer Apple M1 ARM processors.

```bash
docker buildx build --push --tag beamaustralia/php:8.0.7 --platform linux/arm64/v8,linux/amd64 .
```
