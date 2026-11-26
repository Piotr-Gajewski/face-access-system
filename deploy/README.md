# deploy

Running the whole system locally: the services, PostgreSQL with pgvector, Redis, Keycloak, MLflow and S3-compatible object storage. Docker Compose comes first, with a GPU profile for the home PC and a CPU-only profile for demos; a local Kubernetes cluster with Helm comes later.

| | |
|---|---|
| Technology | Docker Compose, later Helm on kind or k3d |
| Status | Planned |
