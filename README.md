# CRM Infra (SFTP → Lambda → RDS) — Terraform

This branch provisions a minimal, working path to ingest bank transactions from an **external SFTP** into an **Aurora/MySQL (RDS)** table via a **Java AWS Lambda**.

**Scope (staging PoC)**
- VPC (1 public subnet) — used by SFTP EC2 only
- EC2: hardened **SFTP server** (OpenSSH, SFTP-only chroot) with **dummy CSV drops**
- RDS: **MySQL 8** (publicly accessible for staging only)
- Lambda (Java 21): runs **outside VPC**, fetches CSV from SFTP, **upserts** into `Transaction` table
- EventBridge Rule: triggers Lambda every 15 minutes

> ⚠️ Costs: t3.micro EC2 + Elastic IP + db.t3.micro RDS. Destroy when done.

---

## Repo layout

```
terraform/
  main.tf
  terraform.tf
  variables.tf
  modules/
    vpc/
    sftp/                 # EC2 SFTP with seeded CSVs
    rds/                  # MySQL 8 (public for staging)
    lambda-sftp-fetch/    # Java Lambda (outside VPC) + schedule
lambda-src/
  pom.xml
  src/main/java/com/example/  # SftpFetchHandler + InMemoryKeyProvider
README.md
```

---

## Prerequisites

- **Terraform** ≥ 1.5
- **AWS CLI** installed (`aws --version`)
- An AWS account with permissions
- **Java 21 + Maven** for building the Lambda JAR
- (Windows) **OpenSSH client** available (`ssh`, `sftp`)

### AWS credentials (local)
Use your own profile; the provider does **not** hardcode a profile.

```powershell
aws configure --profile crm
# region: ap-southeast-1 recommended
```

Then either set `AWS_PROFILE=crm` in your shell or rely on your default profile.

---

## One-time setup (keys)

Create an SSH key for the SFTP user:

```powershell
ssh-keygen -t ed25519 -C "crm-sftp" -f $HOME\.ssh\crm-sftp
```

- Public key: `crm-sftp.pub` (paste into Terraform var)
- Private key: `crm-sftp` (never commit)

If your private key is OpenSSH format and you see parsing errors in Lambda, convert once:

```powershell
ssh-keygen -p -m pem -f $HOME\.ssh\crm-sftp
```

---

## Build the Lambda

```powershell
cd lambda-src
mvn -q -DskipTests package
Copy-Item .\target\sftp-fetch-1.0.0.jar ..\terraform\modules\lambda-sftp-fetch\artifact\sftp-fetch.jar -Force
```

---

## Deploy

From `terraform/`:

```powershell
terraform init
terraform fmt -recursive
terraform validate

# First apply: create VPC + SFTP + RDS + Lambda (outside VPC)
# Provide secrets via -var or a local *.tfvars (git-ignored)
terraform apply `
  -var="sftp_user_pubkey=$(Get-Content $HOME\.ssh\crm-sftp.pub)" `
  -var="sftp_private_key_pem=$(Get-Content $HOME\.ssh\crm-sftp)" `
  -var="db_password=YourStrongPwd123!"
```

Outputs to note:
- `sftp_public_ip`
- `rds endpoint/port/username/db_name`

---

## Verify quickly

### 1) SFTP has CSVs
```powershell
sftp -i $HOME\.ssh\crm-sftp bankhost@<sftp_public_ip>
# at the sftp> prompt:
cd upload/incoming
ls
get transactions_2025-10-10.csv
bye
```

### 2) Invoke Lambda once
```powershell
aws lambda invoke --function-name crm-sftp-fetcher out.json
```
Check **CloudWatch Logs** → you should see CSV read + “Inserted/updated rows …”.

### 3) Check the database
```powershell
mysql -h <rds-endpoint> -P 3306 -u admin -p crmdb
SELECT * FROM Transaction;
```

You should see the dummy rows:
```
ID     ClientID  Transaction  Amount   Date        Status
T0001  C001      D            1200.50  2025-10-09  Completed
...
```

---

## Variables

Common vars are defined in `terraform/variables.tf`. Provide secrets at apply time or via a local `dev.auto.tfvars` (do **not** commit):

```hcl
# dev.auto.tfvars (git-ignored)
sftp_user_pubkey      = "ssh-ed25519 AAAAC3..."
sftp_private_key_pem  = <<EOF
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
EOF
db_password           = "YourStrongPwd123!"
```

---

## Design notes

- **Lambda outside VPC** keeps costs low (no NAT). It talks to:
  - **Public SFTP** (EC2 with Elastic IP)
  - **Public RDS endpoint** (staging only)
- **Upsert** logic prevents duplicates if the same CSV ingests again.
- Dummy CSVs are seeded on the SFTP server at `/upload/incoming`.

---

## Hardening for prod (next branch)

- Move RDS to **private subnets** (no public access)
- Introduce **SQS** + a small **VPC Lambda** that consumes and writes to DB
- Restrict SFTP and RDS SG rules to known IPs / SGs
- Use **KMS CMKs** and **Secrets Manager** for DB creds
- Add **EventBridge** schedule + DLQ on Lambda

---

## Tear down

```powershell
terraform destroy
```

> Be sure to delete any leftover EIPs or snapshots you created manually.
