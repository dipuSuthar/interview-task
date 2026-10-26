# Deployment Guide (Windows / PowerShell)

## 0. Prerequisites
- AWS account + CLI configured (`aws configure`) with an admin-capable user for the one-time bootstrap
- Terraform >= 1.10, Git, Node 20+ (optional, for local tests)
- **A domain in Route 53** (hosted zone id needed) – ACM DNS validation and the HTTPS URL depend on it.
  If your DNS is elsewhere, delegate a subdomain (e.g. `app.example.com`) to a Route 53 hosted zone.

## 1. Bootstrap (once, local)
```powershell
cd terraform\bootstrap
terraform init
terraform apply -var "github_repo=<your-github-user>/<repo-name>"
```
Copy the printed `github_variables_to_set`. (If the account already has a GitHub OIDC provider add `-var create_oidc_provider=false`.)

## 2. Configure GitHub
Repo → Settings → Secrets and variables → Actions → **Variables**: `AWS_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, `RELEASE_BUCKET`.
Or with the GitHub CLI:
```powershell
gh variable set AWS_ROLE_ARN --body "<arn>"
gh variable set AWS_REGION --body "ap-south-1"
gh variable set TF_STATE_BUCKET --body "<bucket>"
gh variable set RELEASE_BUCKET --body "<bucket>"
```
Optional: Settings → Environments → `prod` → add required reviewers.

## 3. Set your domain
Edit `terraform/environments/dev/terraform.tfvars`: `domain_name` and `route53_zone_id`.

## 4. Push your branch and deploy
```powershell
git checkout -b deploy/aws-infra
git add . ; git commit -m "AWS infra + app"
git push -u origin deploy/aws-infra
```
The workflow triggers on pushes to `main` and `deploy/**` (edit `on.push.branches` for another branch name).
Pipeline: **test app → terraform fmt/validate/scan → build + upload artifact → blue/green apply → smoke tests**.
First run creates everything (~15-20 min: NAT, RDS, replica, ACM validation). Later runs do blue/green.

## 5. Verify
```powershell
curl https://app.example.com/health
curl https://app.example.com/api/status
curl -X POST https://app.example.com/api/notes -H "Content-Type: application/json" -d '{\"title\":\"hello\"}'
curl https://app.example.com/api/notes
curl -X POST https://app.example.com/api/storage/check
curl -I http://app.example.com        # expect 301 to https
```
Console checks: ALB listeners/target groups healthy, ASG instances in private subnets, RDS not public, Secrets Manager secret, S3 `alb/AWSLogs/...` objects appearing (log delivery can take ~5 min).
Shell on an instance (no SSH): EC2 console → Connect → Session Manager; logs: `journalctl -u app`, bootstrap log `/var/log/app-bootstrap.log`.

## 6. Day-2 operations
| Task | How |
|---|---|
| New release | push to the branch |
| Rollback | Actions → *Run workflow* → `action=rollback` |
| Keep old fleet warm | run with `keep_standby=true` |
| Prod | run workflow with `environment=prod` (edit prod tfvars first) |
| Tear down (stop costs) | `action=destroy` (dev) – bootstrap stack is destroyed locally with `terraform destroy` |

## Troubleshooting
- **ASG instances unhealthy**: check `/var/log/app-bootstrap.log`; if `dnf` can't find `nodejs22`, run `dnf search nodejs` and set `node_package` in the compute module.
- **ACM stuck "pending validation"**: `route53_zone_id` must be the zone that actually serves `domain_name`.
- **Terraform waits on ASG**: expected – it waits for healthy targets (`wait_for_capacity_timeout = 15m`).
- **Replica create fails**: primary needs backup retention >= 1 (default is 1).

## Screenshots to capture for the submission (save in docs/screenshots/)
1. GitHub Actions run – all jobs green, plus the job summary
2. Browser: `https://<domain>` with padlock, and `/api/status` JSON
3. ALB listeners (443 + 80 redirect) and target groups healthy (blue/green)
4. ASG (instances across 2 AZs) and EC2 instances in private subnets
5. RDS primary + replica (Publicly accessible = No, Encrypted = Yes)
6. Secrets Manager secret, IAM role policy, security group rules
7. S3 buckets incl. ALB log objects
8. VPC resource map (subnets/route tables/NAT/IGW)
