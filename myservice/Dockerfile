FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
&& apt-get install -y curl \
&& rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
RUN mkdir -p /app/certs

RUN useradd -m -u 1000 tronius
RUN chown -R tronius:tronius /app
USER tronius

EXPOSE 8443

# preveri health myservice-a
HEALTHCHECK --interval=30s --timeout=3s   CMD curl -f http://localhost:8443/ping || exit 1

CMD ["python", "main.py"]
