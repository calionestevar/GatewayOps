FROM python:3.11-slim

ARG PACKAGE_NAME=gateway-ops
ARG BUILD_NUMBER=local
ARG COMMIT_SHA=unknown
ENV PACKAGE_NAME=${PACKAGE_NAME} \
    BUILD_NUMBER=${BUILD_NUMBER} \
    COMMIT_SHA=${COMMIT_SHA}

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd --create-home appuser
USER appuser

EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]