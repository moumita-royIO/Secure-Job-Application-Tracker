import json
import boto3
import os

# DynamoDB table name from environment variable
TABLE_NAME = os.environ.get("TABLE_NAME")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        # Validate JobID exists
        if "JobID" not in body:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "JobID is required"})
            }

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
