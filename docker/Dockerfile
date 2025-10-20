# imagen de lambda oficial de aws
FROM public.ecr.aws/lambda/python:3.13

COPY requirements.txt ${LAMBDA_TASK_ROOT}

# instalo dependencias (en este caso solo psycopg2 porque la imagen viene con boto3)
RUN pip install --no-cache-dir -r requirements.txt

# copio código lambda a mi contenedor
COPY lambda_function_local_testing.py ${LAMBDA_TASK_ROOT}

CMD [ "lambda_function_local_testing.lambda_handler" ]
