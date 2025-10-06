# 🌩️ Cloud Infrastructure Challenge — LocalStack Edition

This project implements a **simulated serverless infrastructure** using **Terraform**, **LocalStack**, and **Docker**, since it is intended to be tested **locally** without deploying real AWS cloud infrastructure.

---

##  General Architecture

The architecture simulates an AWS environment with the following components:

- **API Gateway** → HTTP Endpoint (`GET /info`)
- **Lambda Function** → Triggered by the API Gateway; connects to an HTTP backend
- **Backend (fake-service)** → Docker application responding on `/version`
- **CloudWatch Logs** → Captures Lambda output logs
- **Simulated VPC** → Includes logical public/private subnets and security groups
- **PostgreSQL** → Docker container acting as an RDS substitute (optional, for DB connection testing)

> In a real AWS environment, RDS or EC2 instances within private subnets would replace the Docker backend.

---

## ⚙️ Technologies Used

| Component | Description |
|------------|-------------|
| **Terraform** | Infrastructure as Code (IaC) to deploy modular components. |
| **LocalStack** | Local AWS service emulator (Lambda, API Gateway, CloudWatch, etc.). |
| **Docker Compose** | Local orchestrator to spin up LocalStack, backend, and PostgreSQL. |
| **Python (Lambda)** | Lambda function code packaged with dependencies. |

---

## 🐳 Project Structure

```bash
nanlabs/
├── modules/
│   ├── api_gateway/
│   ├── lambda/
│   │   ├── build/lambda.zip
│   │   └── src/app.py
│   ├── logs/
│   ├── rds/
│   └── vpc/
├── .github/
│   ├── workflows/
│        ├── ci.yml/
├── docker-compose.yml        # Orchestrates LocalStack + backend + PostgreSQL
├── main.tf                   # Root infrastructure
├── providers.tf              # AWS + Docker provider configuration
├── variables.tf
├── outputs.tf                # Global outputs
├── .pre-commit-config.yaml   # Git hooks for linting and validation
├── envs
│   └── localstack.tfvars     # Local environment configuration
└── README.md
```

---

## 🚀 Deployment Instructions (LocalStack)

### 1️⃣ Start the base infrastructure with Docker Compose
```bash
docker-compose up -d
```

This will start:
- `localstack-main` (AWS services emulator)
- `ls-api-dev-backend` (fake backend service)
- `pg-local` (optional PostgreSQL instance)

---

### 2️⃣ Initialize Terraform
```bash
terraform init -upgrade
```

---

### 3️⃣ Apply the infrastructure in LocalStack mode
```bash
terraform apply -var-file=envs/localstack.tfvars -auto-approve
```

> ⚙️ The `localstack.tfvars` file defines:
> ```hcl
> use_localstack = true
> region = "us-east-1"
> ```

---

### 4️⃣ View the created resources
```bash
terraform output
```

---

## ✅ Environment Validation

### 🔹 Test the backend
```bash
curl http://localhost:5001/version
```

### 🔹 Invoke the Lambda
```bash
aws --endpoint-url=http://localhost:4566 lambda invoke   --function-name "ls-api-dev-fn" out.json --log-type Tail
cat out.json
```

### 🔹 Invoke the API Gateway
```bash
curl "$(terraform output -raw api_url)"
```

---

## 🧩 Useful Commands

| Action | Command |
|--------|----------|
| List Lambdas | `aws --endpoint-url=http://localhost:4566 lambda list-functions` |
| List APIs | `aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis` |
| List Logs | `aws --endpoint-url=http://localhost:4566 logs describe-log-groups` |
| Destroy resources | `terraform destroy -var-file=envs/localstack.tfvars -auto-approve` |

---

## 🐋 docker-compose.yml Explained

### Overview

The `docker-compose.yml` file orchestrates three main containers:
1. **LocalStack** → Emulates AWS services.
2. **Fake Backend** → Simulates an internal HTTP service reachable by the Lambda.
3. **PostgreSQL** → Emulates an RDS database for local testing.

---

### Typical docker-compose.yml Content

```yaml
version: "3.8"

services:
  localstack:
    container_name: localstack-main
    image: localstack/localstack
    ports:
      - "4566:4566"
      - "4510-4559:4510-4559"
    environment:
      - SERVICES=lambda,logs,apigateway,cloudwatch,iam,s3
      - DEBUG=1
      - LAMBDA_EXECUTOR=docker-reuse
      - LAMBDA_DOCKER_NETWORK=nanlabs
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - AWS_DEFAULT_REGION=us-east-1
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "./.localstack:/var/lib/localstack"
    networks:
      - nanlabs

  backend:
    container_name: ls-api-dev-backend
    image: ghcr.io/nicholasjackson/fake-service:v0.26.2
    environment:
      - LISTEN_ADDR=0.0.0.0:9090
      - NAME=local-backend
    ports:
      - "5001:9090"
    networks:
      - nanlabs

  pg-local:
    container_name: pg-local
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: testuser
      POSTGRES_PASSWORD: testpass
      POSTGRES_DB: testdb
    ports:
      - "5432:5432"
    networks:
      - nanlabs

networks:
  nanlabs:
    driver: bridge
```

---

### Service-by-Service Explanation

| Service | Role | Ports | Notes |
|----------|------|--------|-------|
| **localstack-main** | Emulates AWS (Lambda, API Gateway, CloudWatch, etc.) | 4566 | Core LocalStack service |
| **ls-api-dev-backend** | Local HTTP service responding to `/version` and `/health` | 5001 → 9090 | Acts as a private backend |
| **pg-local** | PostgreSQL DB for testing | 5432 | Emulates a real RDS PostgreSQL instance |
| **Docker Network (`nanlabs`)** | Shared network | — | Enables communication between LocalStack, Lambda, and backend |

---

##  How to Start and Stop the Environment

**Start full environment**
```bash
docker-compose up -d
```

**Check status**
```bash
docker ps
```

**Stop and clean up**
```bash
docker-compose down -v
```

---

- **Author:** Juan Andres Ceballos Beltran  
- **Infrastructure:** Terraform + LocalStack
