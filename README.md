
# CRM SFTP → Lambda → RDS (Staging) — README

This repo contains Terraform + Java code to simulate **Bank Account Transactions Management**:
- A **Docker SFTP** server (running on a developer laptop) exposes CSV files via **ngrok TCP**.
- An **AWS Lambda (Java)** fetches CSVs from SFTP, parses them, and **upserts** rows into the `Transaction` table in RDS.
- Lambda uses a **`fetched_files`** table to **skip already-processed files** (idempotent ingestion).
- Terraform deploys **VPC**, **RDS (MySQL)**, **Lambda**, and optional **EventBridge** schedule.

> Region used in examples: `ap-southeast-1` (Singapore). Adjust if needed.

---

## 0) Prereqs

- **Windows 10/11 + PowerShell**
- **AWS CLI** logged into the correct AWS account (`aws --version`)
- **Terraform v1.5+**
- **Java 21 + Maven**
- **Docker Desktop** (for local SFTP / local MySQL if desired)
- **ngrok** account (free is fine)

---

## 1) Repo layout (key files)

```
terraform/
├── main.tf
├── terraform.tf
├── variables.tf
├── modules/
│   ├── vpc/                     # minimal VPC
│   ├── rds/                     # MySQL RDS (public for staging)
│   └── lambda-sftp-fetch/       # Java Lambda + schedule
│       └── artifact/
└── lambda-src/                  # Java sources (your Maven project)
    ├── pom.xml
    └── src/main/java/com/example/...
```

> **Jar copy path we use in this README:**  
> ```powershell
> Copy-Item .\target\sftp-fetch-1.0.0.jar .\modules\lambda-sftp-fetch\artifact\sftp-fetch.jar -Force
> ```

---

## 2) Local Docker SFTP (for developers)

### 2.1 Install Docker Desktop
- Download & install: https://www.docker.com/products/docker-desktop
- Verify:
  ```powershell
  docker --version
  ```

### 2.2 Pull the SFTP image
We use the community image **`atmoz/sftp`**:
```powershell
docker pull atmoz/sftp
```

### 2.3 Create SFTP folders and a sample CSV
```powershell
mkdir C:\sftpdata\upload\incoming -Force

# Create a sample CSV
@'
ID,ClientID,Transaction,Amount,Date,Status
T1001,C001,D,100.50,2025-10-11,Completed
T1002,C002,W,50.00,2025-10-11,Pending
'@ | Out-File -Encoding utf8 C:\sftpdata\upload\incoming\transactions_sample.csv
```

### 2.4 Run the SFTP container (password mode — easiest)
```powershell
docker run -d --name bank-sftp `
  -p 2222:22 `
  -v C:\sftpdata\upload:/home/bank/upload `
  atmoz/sftp bank:1234:1001
```

- **Username:** `bank`  
- **Password:** `1234`  
- **SFTP path:** `/upload/incoming`

Quick test:
```powershell
sftp -P 2222 bank@localhost
# password: 1234
sftp> ls upload/incoming
```

> **Key-based auth (optional):**  
> If you prefer keys, generate one and mount the public key into the container:
> ```powershell
> ssh-keygen -t ed25519 -C "docker-sftp" -f $HOME\.ssh\docker-sftp
> docker rm -f bank-sftp
> docker run -d --name bank-sftp `
>   -p 2222:22 `
>   -v C:\sftpdata\upload:/home/bank/upload/incoming `
>   -v $HOME\.ssh\docker-sftp.pub:/home/bank/.ssh/keys/id_ed25519.pub:ro `
>   atmoz/sftp bank::1001
> ```
> Then connect:  
> `sftp -i $HOME\.ssh\docker-sftp -P 2222 bank@localhost`

---

## 3) Expose SFTP to AWS via ngrok (TCP tunnel)

### 3.1 Install and login
- Download: https://ngrok.com/download  
- Add auth token from your dashboard:
  ```powershell
  ngrok config add-authtoken <YOUR_TOKEN>
  ```

### 3.2 Start a TCP tunnel for port 2222
```powershell
ngrok tcp 2222
```
You’ll see something like:
```
Forwarding  tcp://0.tcp.ap.ngrok.io:11026 -> localhost:2222
```
Record:
- `SFTP_HOST = 0.tcp.ap.ngrok.io`
- `SFTP_PORT = 11026` (varies each run; keep ngrok window open)

Sanity test (from your PC):
```powershell
sftp -P 11026 bank@0.tcp.ap.ngrok.io
# password: 1234
sftp> ls upload/incoming
```

---

## 4) Build the Lambda (Java 21)

From your **Maven project** folder (where `pom.xml` lives):
```powershell
mvn -q -DskipTests package
# Copy the jar where Terraform expects it:
Copy-Item .\target\sftp-fetch-1.0.0.jar .\modules\lambda-sftp-fetch\artifact\sftp-fetch.jar -Force
```

> The handler class is `com.example.SftpFetchHandler::handleRequest`.
> It supports password auth via `SFTP_PASSWORD` and key auth if a private key is provided.

---

## 5) Terraform deploy (VPC + RDS + Lambda)

### 5.1 Configure variables
Open `terraform\variables.tf` and set defaults or pass via `-var` flags:
- `sftp_host` (e.g., `0.tcp.ap.ngrok.io`)
- `sftp_port` (e.g., `11026`)
- `sftp_user` = `bank`
- `sftp_password` = `1234`
- `db_password` (choose a strong one — used for RDS admin user)

### 5.2 Init & apply
```powershell
cd .\terraform
terraform init
terraform apply `
  -var="sftp_host=0.tcp.ap.ngrok.io" `
  -var="sftp_port=15736" `
  -var="sftp_user=bank" `
  -var="sftp_password=1234" `
  -var="db_password=YourStrongPwd123!"
```

This provisions:
- Minimal **VPC** (1 public subnet)
- **RDS MySQL** (public for staging)
- **Lambda** (outside VPC) that fetches SFTP CSVs and upserts into `Transaction`
- (Optional) EventBridge schedule (see section 7)

**Outputs** will include the RDS endpoint. Keep it handy.

---

## 6) Database Setup

### 6.1 Connect to RDS & create tables
```powershell
mysql -h <rds-endpoint> -u admin -p
```

Create tables:
```sql
CREATE DATABASE IF NOT EXISTS crmdb;
USE crmdb;

CREATE TABLE IF NOT EXISTS `Transaction` (
  `ID`       VARCHAR(32) PRIMARY KEY,
  `ClientID` VARCHAR(32),
  `Transaction` CHAR(1) CHECK (`Transaction` IN ('D','W')),
  `Amount` DECIMAL(10,2),
  `Date` DATE,
  `Status` ENUM('Completed','Pending','Failed')
);

CREATE TABLE IF NOT EXISTS fetched_files (
  filename VARCHAR(255) PRIMARY KEY,
  fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

> The Lambda **upserts** into `Transaction`.  
> It **logs processed filenames** into `fetched_files` to avoid re-processing.

### 6.2 First run & verify
Invoke Lambda once:
```powershell
aws lambda invoke --function-name crm-sftp-fetcher out.json
aws logs tail /aws/lambda/crm-sftp-fetcher --follow
```
Then check data:
```powershell
mysql -h <rds-endpoint> -u admin -p crmdb -e "SELECT * FROM `Transaction`;"
```

Re-run Lambda and observe logs:
- 1st run: `Processing file: transactions_sample.csv` → `✅ Inserted/updated rows`
- 2nd run: `⚠️ Skipping already processed file: transactions_sample.csv`

---

## 7) (Optional) EventBridge schedule

To run the fetcher every 15 minutes, include these resources in `modules/lambda-sftp-fetch/main.tf`:

```hcl
resource "aws_cloudwatch_event_rule" "every_15m" {
  name                = "${var.name}-schedule-15m"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "t" {
  rule      = aws_cloudwatch_event_rule.every_15m.name
  target_id = "lambda"
  arn       = aws_lambda_function.fn.arn
}

resource "aws_lambda_permission" "events_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_15m.arn
}
```

Re-apply Terraform after adding them.

---

## 8) Troubleshooting

- **Lambda times out connecting to SFTP**
  - Ensure **ngrok is running** and you’re using the current `host:port`.
  - Test from your PC: `sftp -P <port> bank@<ngrok-host>`.
  - Verify Docker container is up: `docker ps`.

- **Auth errors (UserAuthException)**
  - If using password mode, make sure `SFTP_PASSWORD=1234` is set in Lambda env (Terraform variable `sftp_password`).
  - If using key mode, ensure you pass the **private key contents** correctly to Lambda and that the container trusts the **public** key.

- **Duplicates inserted**
  - Ensure `fetched_files` table exists.
  - Check Lambda logs for `Skipping already processed file: ...`

- **CSV parsing quirks**
  - The parser strips quotes and ignores headers. For complex CSVs (escaped quotes/commas), swap to **OpenCSV** later.

---

## 9) Clean-up (to avoid charges)

- Stop ngrok (`Ctrl+C` in the ngrok window)
- Stop Docker SFTP:
  ```powershell
  docker rm -f bank-sftp
  ```
- Destroy AWS resources:
  ```powershell
  cd .\terraform
  terraform destroy
  ```

---

## 10) Team Notes (Git/GitHub hygiene)

**Commit:**
- `.tf` files, modules, Java sources, `pom.xml`, this README
- `.terraform.lock.hcl` for provider pinning

**Do NOT commit:**
- `terraform.tfstate*`, `.terraform/`
- Private keys (`.pem`, `.key`), `*.tfvars` with secrets
- Built jars (`target/`), IDE files

Example `.gitignore` entries:
```
.terraform/
terraform.tfstate*
*.pem
*.key
*.tfvars
target/
```

---

## 11) Quick Start (TL;DR)

```powershell
# 1) Run Docker SFTP
docker pull atmoz/sftp
mkdir C:\sftpdata\upload\incoming -Force
# put CSVs into C:\sftpdata\upload\incoming
docker run -d --name bank-sftp -p 2222:22 -v C:\sftpdata\upload:/home/bank/upload atmoz/sftp bank:1234:1001

# 2) Start ngrok TCP tunnel
ngrok tcp 2222   # note host:port

# 3) Build Lambda jar
mvn -q -DskipTests package
Copy-Item .\target\sftp-fetch-1.0.0.jar .\modules\lambda-sftp-fetch\artifact\sftp-fetch.jar -Force

# 4) Terraform apply
cd .\terraform
terraform init
terraform apply -var="sftp_host=<ngrok-host>" -var="sftp_port=<ngrok-port>" -var="sftp_user=bank" -var="sftp_password=1234" -var="db_password=YourStrongPwd123!"

# 5) Test + verify
aws lambda invoke --function-name crm-sftp-fetcher out.json
aws logs tail /aws/lambda/crm-sftp-fetcher --follow
mysql -h <rds-endpoint> -u admin -p crmdb -e "SELECT * FROM `Transaction`;"
```

---

**That’s it.** Your team can follow this README end-to-end to stand up the pipeline and test ingestion safely.
