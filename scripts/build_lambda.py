"""Builds the Lambda package directory (lambda/build) that Terraform zips and deploys.

It contains the function source, its dependencies resolved for the Lambda runtime
(Linux arm64 / Python 3.13, whatever OS this runs on) and the RDS CA bundle used to
verify the database TLS certificate.

Usage: python scripts/build_lambda.py
"""

import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAMBDA_DIR = ROOT / "lambda"
BUILD_DIR = LAMBDA_DIR / "build"

# Must match runtime/architecture in terraform/modules/lambda
PYTHON_VERSION = "3.13"
PLATFORM = "manylinux2014_aarch64"

RDS_CA_BUNDLE_URL = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"


def main():
    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True)

    command = [sys.executable, "-m", "pip", "install", "--quiet", "--no-compile"]
    command += ["--requirement", str(LAMBDA_DIR / "requirements.txt"), "--target", str(BUILD_DIR)]
    # Resolve wheels for the Lambda platform, not for the machine running the build
    command += ["--platform", PLATFORM, "--python-version", PYTHON_VERSION]
    command += ["--implementation", "cp", "--only-binary=:all:"]
    # Fixed arguments built above, no user input reaches the command
    subprocess.run(command, check=True)  # noqa: S603

    for source in (LAMBDA_DIR / "src").glob("*.py"):
        shutil.copy2(source, BUILD_DIR)

    urllib.request.urlretrieve(RDS_CA_BUNDLE_URL, BUILD_DIR / "rds-ca-bundle.pem")

    print(f"Lambda package ready in {BUILD_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
