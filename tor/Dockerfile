FROM golang:alpine AS builder
RUN apk add --no-cache git
ENV http_proxy=http://192.168.1.10:3128
ENV https_proxy=http://192.168.1.10:3128
ENV HTTP_PROXY=http://192.168.1.10:3128
ENV HTTPS_PROXY=http://192.168.1.10:3128
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git /src
WORKDIR /src/main/client
RUN go env -w GOPROXY=https://proxy.golang.org,direct && go build -o /webtunnel

FROM alpine:latest
ENV http_proxy=http://192.168.1.10:3128
ENV https_proxy=http://192.168.1.10:3128
RUN apk add --no-cache tor obfs4proxy
COPY --from=builder /webtunnel /usr/local/bin/webtunnel
COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
EXPOSE 9050 9051 9100
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["tor", "-f", "/etc/tor/torrc"]
