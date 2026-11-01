# Local only: the official Lambda base image ships the Runtime Interface Emulator,
# so the handler runs exactly as in AWS (same Python runtime, same event contract).
FROM public.ecr.aws/lambda/python:3.13

COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir --requirement ${LAMBDA_TASK_ROOT}/requirements.txt --target ${LAMBDA_TASK_ROOT}

COPY src/ ${LAMBDA_TASK_ROOT}/

CMD ["handler.lambda_handler"]
