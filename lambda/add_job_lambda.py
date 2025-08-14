import json
import boto3
import os
import time

TABLE_NAME = os.environ.get("TABLE_NAME")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

def add_job_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        if "JobID" not in body:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "JobID is required"})
            }

        # Add timestamp and notified flag
        body["createdAt"] = int(time.time())
        body["notified"] = False

        # Put item into DynamoDB
        table.put_item(Item=body)

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Job added successfully"})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }

