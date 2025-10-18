import os
import json
import boto3
import psycopg2

DB_ENDPOINT_ADDRESS = os.environ['DB_ENDPOINT_ADDRESS']
DB_SECRET_ARN = os.environ['DB_SECRET_ARN']
DB_NAME = os.environ['DB_NAME']
DB_PORT = int(os.environ.get('DB_PORT', 5432))
REGION = os.environ.get('REGION', "us-east-1")

def lambda_handler(event, context):
    try:

        print(f"Connecting to endpoint: {DB_ENDPOINT_ADDRESS}, database: {DB_NAME}")

        # Retrieve DB credentials from AWS Secrets Manager
        secrets_manager = boto3.client("secretsmanager", region_name=REGION)
        secret_value = secrets_manager.get_secret_value(SecretId=DB_SECRET_ARN)
        secret_dict = json.loads(secret_value["SecretString"])

        username = secret_dict.get("username", "postgres")
        password = secret_dict.get("password")

        # Connect to PostgreSQL
        connection = psycopg2.connect(
            host=DB_ENDPOINT_ADDRESS,
            database=DB_NAME,
            user=username,
            password=password,
            port=DB_PORT
        )

        cursor = connection.cursor()

        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()[0]
        status = "Connected"

        # Clean up
        cursor.close()
        connection.close()
        return {
            "statusCode": 200,
            "body": json.dumps({
                "connection_status": status,
                "database_host": DB_ENDPOINT_ADDRESS,
                "database_version": db_version
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }
