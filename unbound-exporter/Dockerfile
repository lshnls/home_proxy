FROM alpine:latest

RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-prometheus-client \
    unbound \
    openssl

COPY exporter.py /exporter.py

EXPOSE 9167

CMD ["python3", "/exporter.py"]
