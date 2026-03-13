FROM alpine:latest

RUN apk add --no-cache tor
RUN apk add --no-cache obfs4proxy

COPY ./config/torrc /etc/tor/torrc
COPY ./config/bridges.list /etc/tor/bridges.list
#RUN adduser -D tor

#RUN mkdir -p /var/lib/tor && \
#chown -R tor:tor /var/lib/tor

# COPY torrc /etc/tor/torrc

EXPOSE 9050

CMD ["tor","-f","/etc/tor/torrc"]