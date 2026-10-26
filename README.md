# AWS DevOps Practical – Terraform + GitHub Actions (Node.js + MySQL)

Internet → **ALB (HTTPS, ACM)** → **Auto Scaling EC2 (Node.js, blue/green)** → **RDS MySQL (private)**, with ALB access logs → S3.
Everything is Terraform; deployment is a GitHub Actions pipeline using OIDC (no AWS keys in GitHub).

```
app/                       Node.js (Express + mysql2) sample app + tests
terraform/
  bootstrap/               one-time: state bucket, release bucket, GitHub OIDC role
  modules/                 network · security · storage · database · iam · acm · alb · compute
  environments/dev|prod/   thin root modules + tfvars (separate state per env)
scripts/                   package-app.sh · bluegreen.sh (deploy / rollback / destroy)
.github/workflows/deploy.yml
docs/                      ARCHITECTURE.md · DEPLOYMENT.md · architecture.svg · screenshots/
docker-compose.yml         local run on Docker Desktop
```

## Run locally (PowerShell, Docker Desktop)
```powershell
docker compose up --build
curl http://localhost:3000/api/status
```

## Deploy
Follow **docs/DEPLOYMENT.md** (bootstrap once, set 4 GitHub variables, push your branch).

## What the app exposes
| Endpoint | Purpose |
|---|---|
| `GET /health` | ALB health check (shallow) |
| `GET /api/status` | Deep check: colour, version, instance id, primary + replica DB state |
| `GET/POST /api/notes` | Reads from the replica, writes to the primary |
| `POST /api/storage/check` | Proves the instance role can read/write the app S3 bucket |
| `GET /` | Banner coloured by active fleet (blue/green) |
