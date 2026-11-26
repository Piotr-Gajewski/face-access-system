# web

Admin panel, the only place where people work with the system. Users enrol their face and see their access history; administrators manage doors, devices, thresholds and watch access attempts live. The panel makes no security decisions: it shows data and sends commands to `access-service`, which signs users in through a Backend-for-Frontend (tokens stay on the server).

| | |
|---|---|
| Technology | React, TypeScript, Vite; API client generated from the OpenAPI specification of `access-service` |
| Status | Planned |
