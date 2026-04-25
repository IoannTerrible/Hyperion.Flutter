FROM nginx:alpine

RUN apk add --no-cache apache2-utils \
 && htpasswd -bc /etc/nginx/.htpasswd HypTest 25042026HomeWork \
 && apk del apache2-utils

COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
