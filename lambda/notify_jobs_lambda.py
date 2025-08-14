import boto3
import time
import csv
import io
import os

TABLE_NAME = os.environ.get("TABLE_NAME")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)
sns = boto3.client("sns")

def notify_old_jobs_handler(event, context):
    now = int(time.time())
    three_days_ago = now - (3 * 24 * 60 * 60)

    # Scan DynamoDB for jobs older than 3 days and not notified
    response = table.scan()
    jobs_to_notify = []

    for item in response.get("Items", []):
        created_at = item.get("createdAt", 0)
        notified = item.get("notified", False)

        if created_at <= three_days_ago and not notified:
            jobs_to_notify.append(item)
            # Mark as notified
            table.update_item(
                Key={"JobID": item["JobID"]},
                UpdateExpression="SET notified = :n",
                ExpressionAttributeValues={":n": True}
            )

    if not jobs_to_notify:
        return {"statusCode": 200, "body": "No jobs to notify."}

    # Generate CSV in memory
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=["JobID", "Title", "Company", "createdAt"])
    writer.writeheader()
    for job in jobs_to_notify:
        writer.writerow({
            "JobID": job["JobID"],
            "Title": job.get("Title", ""),
            "Company": job.get("Company", ""),
            "createdAt": job.get("createdAt", "")
        })
    csv_content = output.getvalue()

    # Send CSV via SNS
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="Job Report - Jobs Older Than 3 Days",
        Message=csv_content
    )

    return {"statusCode": 200, "body": "CSV notification sent successfully."}

