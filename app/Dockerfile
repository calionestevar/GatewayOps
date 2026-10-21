FROM python:3.11-slim

ARG PACKAGE_NAME=gateway-ops
ARG BUILD_NUMBER=local
ARG COMMIT_SHA=unknown
ENV PACKAGE_NAME=${PACKAGE_NAME} \
    BUILD_NUMBER=${BUILD_NUMBER} \
    COMMIT_SHA=${COMMIT_SHA} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y setuptools

# Copy only application code, not the whole context
COPY app.py .

RUN useradd --create-home appuser
USER appuser

EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]