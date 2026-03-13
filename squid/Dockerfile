FROM alpine:latest

RUN apk add --no-cache squid
RUN apk add --no-cache openssl

RUN mkdir -p /etc/squid/ssl
COPY ./config/squid.conf /etc/squid/squid.conf
COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3128 8081 8082
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["squid", "-N", "-f", "/etc/squid/squid.conf"]