# access-service

Core of the system and the only owner of its data: people, face templates, doors, policies, devices and the audit log. It runs each verification session (challenge, frames bound to the session), calls `biometric-service`, compares templates and makes the access decision. If a dependency does not answer, the decision is to deny access.

Interfaces: REST for the panel, WebSocket with a binary protocol for door readers, STOMP for the live view.

| | |
|---|---|
| Technology | Java 25, Spring Boot 4, PostgreSQL with pgvector, Redis, Keycloak (OAuth2 through a Backend-for-Frontend) |
| Status | Planned |
