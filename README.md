A serverless **backend** application to track job applications, notify about pending jobs older than 3 days, and automatically clean up old records. Built with **AWS Lambda, DynamoDB, API Gateway, SNS, and Terraform**.

## Features
- Add jobs via an HTTP API (POST `/jobs`).
- Jobs are stored in DynamoDB with `createdAt` timestamp and TTL `(7 days)`.
- Scheduled notifications for jobs older than 3 days and has no status update.
- CSV / pretty table notifications sent via SNS email.
- CloudWatch logging for debugging and monitoring.
- Infrastructure-as-code deployment via Terraform except for the SNS.

<img width="500" height="900" alt="architecture" src="https://github.com/user-attachments/assets/17f54380-5772-4039-a2c3-5eecd95ca0ec" />

## Setup

1) Clone the repository

```bash
git clone <repo-url>
cd Secure-Job-Application-Tracker
```

2) Install Terraform and configure AWS CLI credentials

Modify main.tf if needed:
DynamoDB table name
Lambda environment variables
SNS topic ARN

3) Package Lambda functions as ZIP

```bash
cd lambdas/add_job
zip -r ../../lambda_add_job.zip .
```
```
cd ../notify_jobs
zip -r ../../lambda_notify_jobs.zip .
```

4) Deploy the config from main.tf as infrastructure

```bash
terraform init
terraform plan
terraform apply
```

5) Subscribe an email to the SNS topic for notifications.

## Usage

- Add a Job via API

```bash
curl -X POST <API_GATEWAY_URL>/jobs \
-H "Content-Type: application/json" \
-d '{
    "JobID": "xxx",
    "Title": "Backend Engineer",
    "Company": "xxx",
    "createdAt": <epoch time>
}'
```

## Notifications

- Notify Jobs Lambda runs automatically (EventBridge)
- Sends CSV in table format via email with jobs older than 3 days. You can followup on the job status accordingly.

## Security Layers in the Architecture

1) DynamoDB is never exposed directly to the internet. All reads/writes happen only via Lambda functions. This prevents any SQL injection or direct query attacks since there’s no endpoint for attackers to hit.
2) DynamoDB encrypts all data at rest (AES-256) by default.
3) Gateway & SNS use HTTPS (TLS 1.2/1.3) for all communication.
   
