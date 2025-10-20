import boto3
import os
import psycopg2
from datetime import datetime

#
DB_HOST = os.environ['DB_HOST'] # RDS Endpoint
DB_USER = os.environ['DB_USER'] # The DB user enabled for IAM Auth
DB_NAME = os.environ['DB_NAME']
DB_PORT = 5432
REGION_NAME = os.environ['REGION_NAME'] 

# 1. Generate the Authentication Token (Temporary Password)
def generate_db_auth_token(db_host, db_port, db_user, region_name):
    """
    Uses Boto3 to generate an RDS Auth Token.
    """
    client = boto3.client('rds', region_name=region_name)
    token = client.generate_db_auth_token(
        DBHostname=db_host,
        Port=db_port,
        DBUsername=db_user,
        Region=region_name
    )
    return token

def lambda_handler(event, context):
    # Retrieve the temporary token
    token = generate_db_auth_token(DB_HOST, DB_PORT, DB_USER, REGION_NAME)
    
    conn = None
    try:
        # 2. Connect using the token as the password
        print(f"Connecting to database {DB_NAME} as user {DB_USER}...")
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=token, # <--- Use the temporary token here
            sslmode='require' 
        )
        
        # 3. Execute queries to get connection and status information
        cursor = conn.cursor()
        
        # Query 1: Get the PostgreSQL version
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()[0]
        
        # Query 2: Get the current authenticated user (should match DB_USER)
        cursor.execute("SELECT current_user;")
        current_db_user = cursor.fetchone()[0]

        # Query 3: Get the current database time
        cursor.execute("SELECT NOW();")
        db_time = cursor.fetchone()[0].isoformat() # Convert datetime object to ISO string
        
        cursor.close()
        
        print("Database connection and queries successful.")
        
        # 4. Return the gathered information
        return {
            'statusCode': 200,
            'body': {
                'message': 'Successfully connected and retrieved database status.',
                'database_host': DB_HOST,
                'authenticated_user': current_db_user,
                'database_name': DB_NAME,
                'database_version': db_version,
                'database_current_time': db_time,
                'lambda_timestamp': datetime.utcnow().isoformat() + 'Z'
            }
        }

    except Exception as e:
        # Log the error and return a 500 status
        print(f"ERROR: Could not connect to RDS or execute query: {e}")
        return {
            'statusCode': 500,
            'body': f'Database connection or query error: {e}'
        }

    finally:
        # 5. Ensure the connection is closed
        if conn:
            conn.close()
            print("Database connection closed.")