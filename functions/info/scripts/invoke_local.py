"""Runs the real Lambda handler once, in this process, and prints the response.

The DB_* environment variables say which database to use; see local/.env.example.
Exit status is 0 only when the handler answers 200.
"""

import json
import sys
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from info_api import handler  # noqa: E402


def main() -> int:
    event = json.loads((ROOT / "events" / "get-info.json").read_text())
    context = SimpleNamespace(aws_request_id="local-invoke")

    response = handler.lambda_handler(event, context)

    print(f"HTTP {response['statusCode']}")
    print(json.dumps(json.loads(response["body"]), indent=2))
    return 0 if response["statusCode"] == 200 else 1


if __name__ == "__main__":
    sys.exit(main())
