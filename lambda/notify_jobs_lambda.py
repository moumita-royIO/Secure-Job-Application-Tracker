import boto3
import time
import os
import datetime

# Environment variables
TABLE_NAME = os.environ.get("TABLE_NAME")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")

# AWS clients
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)
sns = boto3.client("sns")

def notify_old_jobs_handler(event, context):
    # Debug: log Lambda invocation
    print("Lambda invoked, event:", event)

    now = int(time.time())
    three_days_ago = now - (3 * 24 * 60 * 60)
    print("Current time:", now, "Three days ago:", three_days_ago)

    # Scan DynamoDB
    response = table.scan()
    print("Scanned", len(response.get('Items', [])), "items from DynamoDB")
    jobs_to_notify = []

    for item in response.get("Items", []):
        print("Checking item:", item)
        created_at = int(item.get("createdAt", 0))  # convert Decimal to int
        notified = item.get("notified", False)

        if created_at <= three_days_ago and not notified:
            jobs_to_notify.append(item)
            # Mark as notified
            table.update_item(
                Key={"JobID": item["JobID"]},
                UpdateExpression="SET notified = :n",
                ExpressionAttributeValues={":n": True}
            )
            print("Adding JobID=", item["JobID"], "to notification list")

    if not jobs_to_notify:
        print("No jobs matched the criteria for notification.")
        return {"statusCode": 200, "body": "No jobs to notify."}

    # Generate pretty table for email
    columns = ["JobID", "Title", "Company", "Created At"]
    widths = {col: len(col) for col in columns}

    for job in jobs_to_notify:
        widths["JobID"] = max(widths["JobID"], len(job["JobID"]))
        widths["Title"] = max(widths["Title"], len(job.get("Title", "")))
        widths["Company"] = max(widths["Company"], len(job.get("Company", "")))
        created_at_str = datetime.datetime.utcfromtimestamp(int(job.get("createdAt", 0))).strftime("%Y-%m-%d")
        widths["Created At"] = max(widths["Created At"], len(created_at_str))

    # Build table string
    lines = []
    header_line = " | ".join(col.ljust(widths[col]) for col in columns)
    lines.append(header_line)
    lines.append("-+-".join("-" * widths[col] for col in columns))

    for job in jobs_to_notify:
        created_at_str = datetime.datetime.utcfromtimestamp(int(job.get("createdAt", 0))).strftime("%Y-%m-%d")
        row = [
            job["JobID"].ljust(widths["JobID"]),
            job.get("Title", "").ljust(widths["Title"]),
            job.get("Company", "").ljust(widths["Company"]),
            created_at_str.ljust(widths["Created At"])
        ]
        lines.append(" | ".join(row))

    pretty_content = "\n".join(lines)
    print("Pretty table generated:\n", pretty_content)

    # Send via SNS
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="Job Report - Jobs Older Than 3 Days",
        Message=pretty_content
    )
    print("Notification sent via SNS")

    return {"statusCode": 200, "body": "CSV notification sent successfully."}
