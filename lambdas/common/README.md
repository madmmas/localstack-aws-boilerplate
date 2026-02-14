# Common dependencies for Lambdas

Shared Python deps (e.g. Powertools) used at **build time** only. They are bundled into each Lambda zip; no AWS Lambda layer is used (not supported in LocalStack free).

- **requirements.txt**: List of packages to install and bundle.
- **Build**: From repo root, `make package` runs `build-common-deps` then builds each Lambda zip with these deps included.
