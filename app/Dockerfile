FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONUNBUFFERED=1

# Run as a non-root user (good practice)
RUN useradd -m appuser
USER appuser

EXPOSE 5000
# 1 worker + threads: Prometheus counters live in one process, so /metrics is accurate
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", "app:app"]
