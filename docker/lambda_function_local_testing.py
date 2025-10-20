# src/function_code/lambda_function.py
import json
import os
import psycopg2 
import time

# variables definidas en docker-compose
DB_HOST = os.environ['DB_HOST'] 
DB_USER = os.environ['DB_USER'] 
DB_NAME = os.environ['DB_NAME']
DB_PASSWORD = os.environ['DB_PASSWORD']

def lambda_handler(event, context):
    conn = None
    try:
        # me conecto con las credenciales definidas
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        
        # query sencilla de version de db
        with conn.cursor() as cur:
            cur.execute("SELECT version();")
            db_version = cur.fetchone()[0]
        
        db_status = f"SUCCESS! Connected to DB version: {db_version}"

    except Exception as e:
        # failure
        db_status = f"DB Connection Failed: {e}"
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Database connection failed", "details": str(e)})
        }
    finally:
        if conn:
            conn.close()

    # éxito
    response_data = {
        "message": "Local Lambda tested successfully with direct DB connection.",
        "timestamp": time.time(),
        "database_status": db_status
    }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(response_data)
    }