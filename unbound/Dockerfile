FROM alpine:latest

RUN apk add --no-cache \ 
    unbound \
    ca-certificates

EXPOSE 53/tcp 53/udp

CMD ["unbound","-d", "-c", "/etc/unbound/unbound.conf"]
