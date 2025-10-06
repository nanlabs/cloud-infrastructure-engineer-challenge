import json
import os
import urllib.request

def check_backend_http(url):
    try:
        with urllib.request.urlopen(url, timeout=2) as resp:
            body = resp.read().decode("utf-8", errors="ignore")
            try:
                meta = json.loads(body)
            except Exception:
                meta = {"raw": body}
            return str(resp.status), meta
    except Exception as e:
        return f"error: {e}", {}

def handler(event, context):
    backend_url = os.environ.get("BACKEND_URL", "")
    http_status, http_meta = check_backend_http(backend_url) if backend_url else ("skip", {})

    body = {
        "message": "info",
        "connection_status": {
            "http_backend": http_status,
            "database": "skip"  # DB deshabilitada en local
        },
        "backend_metadata": http_meta,
        "database_metadata": {},
        "context": {
            "lambda": os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "local"),
            "request_id": getattr(context, "aws_request_id", "local")
        }
    }
    return {"statusCode": 200, "headers": {"Content-Type":"application/json"}, "body": json.dumps(body)}
