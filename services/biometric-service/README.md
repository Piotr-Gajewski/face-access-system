# biometric-service

Stateless face analysis service, reachable only from `access-service` and without database access. Modules:

- **K** – classical recognition: Haar cascade detection, LBP histogram as the feature vector
- **S** – neural recognition: network detector, quality check, face embedding
- **P** – passive liveness on single frames
- **W** – active challenge: face landmarks and head pose, checking that the sequence follows the command

The variant is chosen per request. Every response names the model and its version, so `access-service` can record them in the audit log. Model weights are not stored in this repository; each model is listed in a model registry with its source and licence.

| | |
|---|---|
| Technology | Python 3.12, FastAPI, ONNX Runtime (GPU and CPU images), MediaPipe for the challenge |
| Status | Planned |
