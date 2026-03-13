FROM alpine:latest

RUN apk add --no-cache privoxy

COPY ./config/config /etc/privoxy/config
COPY ./config/user.action /etc/privoxy/user.action
COPY ./config/match-all.action /etc/privoxy/match-all.action
COPY ./config/default.action /etc/privoxy/default.action

EXPOSE 8118

CMD ["privoxy", "--no-daemon", "/etc/privoxy/config"]
