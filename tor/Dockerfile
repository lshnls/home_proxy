FROM alpine:latest

RUN apk add --no-cache \
    tor \
    obfs4proxy

COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY ./config/torrc /etc/tor/torrc
COPY ./config/bridges.list /etc/tor/bridges.list


#RUN chmod +x /usr/bin/docker-entrypoint.sh

EXPOSE 9050

#ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["tor", "-f", "/etc/tor/torrc"]
