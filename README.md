# Microservices Voting System

Production-grade, highly available voting platform built with **Quarkus (Java 17)**, **Traefik**, **MariaDB**, **Redis**, **Graylog**, **OpenSearch**, and **Jaeger**.

---

## 🏗️ Project Overview & Architecture

The system is composed of three Quarkus microservices orchestrated via Docker Compose and routed through a Traefik Reverse Proxy with zero-downtime Blue-Green deployment capabilities.

```
                   ┌────────────────────────┐
                   │     Traefik Proxy      │
                   └───────────┬────────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │ (Host: vote.dio.localhost)                │
         ▼                     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ election-mgmt    │  │    voting-app    │  │    result-app    │
│  (/api)          │  │  (/api/voting)   │  │    (/)           │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                     │
         └──────────┬──────────┴──────────┬──────────┘
                    ▼                     ▼
             ┌────────────┐        ┌────────────┐
             │  MariaDB   │        │   Redis    │
             └────────────┘        └────────────┘
```

### Microservices:
* **election-management**: Service for defining elections, candidates, and administrative rules.
* **voting-app**: High-throughput service for receiving and processing cast votes.
* **result-app**: Real-time aggregation and presentation of election results.

### Infrastructure Components:
* **Traefik Proxy (80 / 8080)**: Dynamic routing, load balancing, and entry point management.
* **MariaDB**: Relational persistence layer for election configuration data.
* **Redis**: In-memory data store for caching and rapid vote buffering.
* **Graylog + MongoDB + OpenSearch**: Centralized logging pipeline receiving GELF logs over UDP (12201).
* **Jaeger**: Distributed OpenTelemetry tracing collector and visualization interface.

---

## ⚡ Setup & Installation Instructions

### Prerequisites
* **Docker** (v20.10+) and **Docker Compose** (v2.0+)
* **Java Development Kit (JDK 17)** or higher
* **Bash** shell environment

### Quick Start
1. **Clone the Repository:**
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Start the Infrastructure and Microservices:**
   ```bash
   docker compose up -d
   ```

3. **Access Services:**
   * **Voting App / API**: `http://vote.dio.localhost/api/voting`
   * **Election Management API**: `http://vote.dio.localhost/api`
   * **Result App**: `http://vote.dio.localhost/`
   * **Graylog Logging Console**: `http://logging.private.dio.localhost`
   * **Jaeger Telemetry Dashboard**: `http://telemetry.private.dio.localhost`

---

## 🔑 Environment Variables Required

| Environment Variable | Description | Default Value |
| :--- | :--- | :--- |
| `MARIADB_ROOT_PASSWORD` | Database root password | `root` |
| `MARIADB_DATABASE` | Initial database name | `election` |
| `GRAYLOG_PASSWORD_SECRET` | Secret key for Graylog password encryption | `forpasswordencryption_secret_16chars` |
| `GRAYLOG_ROOT_PASSWORD_SHA2` | SHA-256 hash for Graylog root user | `8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918` |
| `OPENSEARCH_SECURITY_DISABLED` | Flag to disable OpenSearch internal security plugin | `true` |
| `JAEGER_BASICAUTH_USERS` | BasicAuth credentials for Jaeger UI access | `admin:$$2y$$05$$...` |
| `GELF_HOST` / `QUARKUS_LOG_HANDLER_GELF_HOST` | Hostname of Graylog GELF server | `graylog` |
| `GELF_PORT` / `QUARKUS_LOG_HANDLER_GELF_PORT` | Port for Graylog GELF server | `12201` |
| `OTLP_ENDPOINT` | OpenTelemetry collector endpoint | `http://jaeger:4317` |

---

## 🧪 How to Run Builds & Test Suite

### 1. Build Microservices Locally
Each service includes a Maven wrapper (`mvnw`). You can compile and package any service individually:
```bash
cd election-management
./mvnw clean package
```

To compile all microservices:
```bash
(cd election-management && ./mvnw test-compile) && \
(cd voting-app && ./mvnw test-compile) && \
(cd result-app && ./mvnw test-compile)
```

### 2. CI/CD Build Script
Build docker image for a service:
```bash
./cicd-build.sh voting-app
```

### 3. Zero-Downtime Blue-Green Deployment
Deploy a new version using Blue-Green strategy:
```bash
./cicd-blue-green-deployment.sh voting-app 1.0.1
```

### 4. Automated Test Suite
Run the automated deployment and infrastructure validation suite:
```bash
./scripts/test_deployment_scripts.sh
```

---

## 🔒 Security Considerations & Vulnerabilities Resolved

During the code audit and security hardening phase, several critical vulnerabilities and infrastructure risks were remediated:

1. **Unauthenticated Dashboard Exposure**:
   * *Issue*: Traefik dashboard had `--api.insecure=true` enabled, exposing raw management ports.
   * *Remediation*: Removed `--api.insecure=true` and secured dashboard routing.
2. **Hardcoded Credentials & Unbound Environment Secrets**:
   * *Issue*: Hardcoded passwords in `docker-compose.yml` for MariaDB and Graylog.
   * *Remediation*: Replaced hardcoded credentials with environment variable bindings with configurable defaults.
3. **Data Loss & Stateless Database Deployment**:
   * *Issue*: MariaDB, Redis, MongoDB, and OpenSearch lacked persistent storage volumes.
   * *Remediation*: Added persistent Docker volume definitions (`mariadb_data`, `redis_data`, `mongodb_data`, `opensearch_data`).
4. **Unsafe Shell Scripts & Infinite Deployment Loops**:
   * *Issue*: `cicd-blue-green-deployment.sh` lacked error handling (`set -e`), contained infinite polling loops without timeout bounds, and failed when killing multi-line blue container IDs.
   * *Remediation*: Enforced `set -euo pipefail`, added argument validation, implemented a 120-second timeout on container health polling, and used `xargs -r docker kill` for safe signal transmission.
