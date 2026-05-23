FROM alpine:latest

RUN sed -i 's|https://dl-cdn.alpinelinux.org/alpine|https://mirror.yandex.ru/mirrors/alpine|g' /etc/apk/repositories && \
    apk add --no-cache \ 
    nginx \ 
    openssl


RUN mkdir -p /etc/nginx/certs
COPY ./generate_nginx_cert.sh /usr/local/bin/generate_nginx_cert.sh
RUN chmod +x /usr/local/bin/generate_nginx_cert.sh

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/generate_nginx_cert.sh"]

CMD ["nginx", "-g", "daemon off;"]
