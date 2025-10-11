<<<<<<< Updated upstream
# terraform
=======
# CRM SFTP → Lambda → RDS (Staging) — README

This repository contains Terraform and Java code to simulate **bank transaction ingestion**:
- A **Docker SFTP** server on your laptop exposes CSV files.
- An **ngrok TCP tunnel** makes that SFTP reachable from the internet.
- An **AWS Lambda (Java)** fetches CSVs and inserts into **RDS MySQL**.
- A small `fetched_files` table ensures **each file is processed only once**.

> ⚠️ This is a staging/demo setup focused on simplicity. For production, see the **Hardening** section at the end.

---

## 0) Prerequisites

- Windows 10/11 with **PowerShell**
- **Docker Desktop**
- **Java 21** + **Maven 3.9+**
- **Terraform 1.5+**
- **AWS CLI v2** (authenticated to your team account)
- An **ngrok** account (free tier is fine)

---

## 1) Project Structure (expected)

```
terraform/
├── main.tf
├── terraform.tf
├── variables.tf
├── .terraform.lock.hcl
├── modules/
│   ├── vpc/
│   ├── rds/
│   ├── sftp/                  # (optional EC2 SFTP used in earlier steps)
│   └── lambda-sftp-fetch/
│       ├── artifact/
│       │   └── sftp-fetch.jar
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
lambda-src/
├── pom.xml
└── src/main/java/com/example/
    ├── SftpFetchHandler.java
    └── InMemoryKeyProvider.java   # optional if using key auth
```

---

## 2) Local Docker SFTP (password auth)

We use the `atmoz/sftp` image. The server exposes an **`upload/incoming`** folder where you drop CSV files.

**Folder layout on Windows (example):**
```
C:\Users\<you>\crm-tx-local-sftp\sftp\
├── incoming\transactions_sample.csv
```

**Run the container (user = `bank`, password = `1234`):**
```powershell
docker rm -f bank-sftp 2>$null

docker run -d --name bank-sftp `
  -p 2222:22 `
  -v C:\Users\<you>\crm-tx-local-sftp\sftp\incoming:/home/bank/upload/incoming `
  atmoz/sftp bank:1234:1001
```

**Test locally:**
```powershell
sftp -P 2222 bank@localhost
# password: 1234
sftp> ls upload/incoming
```

---

## 3) Expose SFTP via ngrok TCP

Install ngrok → sign in → copy your authtoken from dashboard.

```powershell
ngrok config add-authtoken <YOUR_TOKEN>
ngrok tcp 2222
```

You will see output like:
```
Forwarding  tcp://0.tcp.ap.ngrok.io:11026  -> localhost:2222
```

**Record these:**
- `SFTP_HOST = 0.tcp.ap.ngrok.io`
- `SFTP_PORT = 11026`  (port changes each session)

**Sanity check:**
```powershell
sftp -P 11026 bank@0.tcp.ap.ngrok.io
# password: 1234
sftp> ls upload/incoming
```

> Keep the ngrok window **open** while Lambda runs. Closing it changes the host/port.

---

## 4) Build the Java Lambda (CSV → MySQL with dedupe)

From the `lambda-src` folder:

```powershell
mvn -q -DskipTests package
```

Copy the fat JAR into Terraform’s module **exactly like this**:

```powershell
Copy-Item .\target\sftp-fetch-1.0.0.jar .\modules\lambda-sftp-fetch\artifact\sftp-fetch.jar -Force
```

> The handler prints CSV contents and upserts into the `Transaction` table.  
> It also writes to `fetched_files(filename)` so **each file is processed only once**.

---

## 5) Terraform — deploy VPC, RDS, Lambda (outside VPC)

From the `terraform` folder:

```powershell
terraform init
terraform apply `
  -var="sftp_host=0.tcp.ap.ngrok.io" `
  -var="sftp_port=11026" `
  -var="sftp_user=bank" `
  -var="sftp_password=1234" `
  -var="db_password=YourStrongPwd123!"
```

When apply finishes, note the RDS endpoint output.

**Create required tables (once):**
```sql
CREATE TABLE IF NOT EXISTS `Transaction` (
  `ID`       VARCHAR(10) PRIMARY KEY,
  `ClientID` VARCHAR(10),
  `Transaction` CHAR(1) CHECK (`Transaction` IN ('D','W')),
  `Amount`   DECIMAL(10,2),
  `Date`     DATE,
  `Status`   ENUM('Completed','Pending','Failed')
);

CREATE TABLE IF NOT EXISTS fetched_files (
  filename   VARCHAR(255) PRIMARY KEY,
  fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

> You can run these in MySQL Workbench or CLI (use the RDS endpoint from Terraform outputs).

---

## 6) Invoke & Verify

**Manual run:**
```powershell
aws lambda invoke --function-name crm-sftp-fetcher out.json
```

**Tail logs:**
```powershell
aws logs tail /aws/lambda/crm-sftp-fetcher --follow
```

Expected first run:
```
Connecting to 0.tcp.ap.ngrok.io:11026 as bank
---- transactions_sample.csv ----
✅ Inserted/updated rows from transactions_sample.csv
```

Expected second run (idempotent):
```
⚠️ Skipping already processed file: transactions_sample.csv
```

**Check DB rows:**
```sql
SELECT * FROM `Transaction`;
SELECT * FROM fetched_files;
```

---

## 7) Schedule (EventBridge)

You can enable a scheduled run (e.g., every 15 minutes) in the Lambda module:

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

Re-`terraform apply` to activate.

---

## 8) Troubleshooting

**Timeouts connecting to SFTP**
- Ensure Docker container is running: `docker ps`
- Ensure `ngrok tcp 2222` is active, and Terraform uses the shown host:port
- Test from your PC: `sftp -P <port> bank@0.tcp.ap.ngrok.io`

**Auth errors**
- Using password auth? Confirm `-var="sftp_password=1234"` and Lambda code checks `SFTP_PASSWORD` first.
- If switching to key auth, ensure your handler uses `OpenSSHKeyFile` and you pass the **contents** of the private key file safely via SSM/var.

**Duplicate rows**
- We use `INSERT ... ON DUPLICATE KEY UPDATE` and a `fetched_files` table. If you see dupes, verify your `ID` is the primary key and `fetched_files` gets a row per processed file.

---

## 9) Security & Hardening (later)

- Move RDS to **private subnets**, turn off `publicly_accessible`.
- Run a small **“DB writer” Lambda inside the VPC**, and have the public Lambda send filenames over **SQS**.
- Replace ngrok with a **permanent SFTP host** (EC2) + fixed Elastic IP.
- Store secrets in **AWS SSM Parameter Store** or **Secrets Manager**, not as plain vars.

---

## 10) Quick Reference (copy/paste)

**Build & copy jar:**
```powershell
mvn -q -DskipTests package
Copy-Item .\target\sftp-fetch-1.0.0.jar .\modules\lambda-sftp-fetch\artifact\sftp-fetch.jar -Force
```

**Run Docker SFTP (password):**
```powershell
docker rm -f bank-sftp 2>$null
docker run -d --name bank-sftp `
  -p 2222:22 `
  -v C:\Users\<you>\crm-tx-local-sftp\sftp\incoming:/home/bank/upload/incoming `
  atmoz/sftp bank:1234:1001
```

**Start ngrok TCP:**
```powershell
ngrok tcp 2222
# Use the displayed tcp host:port in terraform apply
```

**Terraform apply (outside VPC Lambda + RDS):**
```powershell
terraform apply `
  -var="sftp_host=0.tcp.ap.ngrok.io" `
  -var="sftp_port=<PORT_FROM_NGROK>" `
  -var="sftp_user=bank" `
  -var="sftp_password=1234" `
  -var="db_password=YourStrongPwd123!"
```

**Invoke & tail logs:**
```powershell
aws lambda invoke --function-name crm-sftp-fetcher out.json
aws logs tail /aws/lambda/crm-sftp-fetcher --follow
```

---

## 11) Appendix — CSV format (dummy data)

Expected CSV header:
```
ID,ClientID,Transaction,Amount,Date,Status
```
- `Transaction`: `D` (deposit) or `W` (withdrawal)
- `Status`: `Completed|Pending|Failed`
- `Date`: `YYYY-MM-DD`

Example:
```
T0001,C001,D,1200.50,2025-10-09,Completed
T0002,C001,W,100.00,2025-10-09,Completed
```
>>>>>>> Stashed changes
