FROM alpine:latest

RUN apk add --no-cache \
    unbound \
    openssl \
    ca-certificates

# Сгенерируем control-сертификаты один раз при сборке
RUN mkdir -p /etc/unbound && unbound-control-setup -d /etc/unbound

EXPOSE 53/tcp 53/udp 8953/tcp

CMD ["unbound","-d", "-c", "/etc/unbound/unbound.conf"]
