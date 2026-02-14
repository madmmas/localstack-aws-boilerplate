# Lambda layer: Powertools (Log + Metrics)

Shared dependencies for all Lambdas. Build produces `dist/layer.zip` with structure:

```
layer.zip
└── python/
    └── aws_lambda_powertools/
        ...
```

Build (from repo root): `make package-layer` or from here: `uv pip install -t build/python aws-lambda-powertools && cd build && zip -r ../dist/layer.zip python`.
