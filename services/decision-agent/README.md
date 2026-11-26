# decision-agent

Optional last stage of the access decision, enabled in configuration globally or per door. During a session `access-service` sends it model results and metadata (time, device, attempt history), never images. It can only make a decision stricter: ask for an extra challenge or deny access. It runs with a timeout; when it does not answer, the rule-based decision stands and the event is logged.

| | |
|---|---|
| Technology | Python; the approach (rules, classical ML model or local language model) is not decided yet |
| Status | Optional (variant A), not part of the core study |
