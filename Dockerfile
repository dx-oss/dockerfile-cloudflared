FROM golang:alpine as gobuild

RUN apk update; \
    apk add git gcc build-base; \
    go get -v github.com/cloudflare/cloudflared/cmd/cloudflared

WORKDIR /go/src/github.com/cloudflare/cloudflared/cmd/cloudflared

RUN GOOS=linux GOARCH=amd64 go build ./

FROM alpine

ENV DNS1 1.1.1.1
ENV UPSTREAM1 https://${DNS1}/.well-known/dns-query
ENV DNS2 1.0.0.1
ENV UPSTREAM2 https://${DNS2}/.well-known/dns-query
ENV PORT 5054

RUN echo 'http://dl-cdn.alpinelinux.org/alpine/edge/main' > /etc/apk/repositories ; \
    echo 'http://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories; \
    adduser -S cloudflared; \
    apk add --no-cache ca-certificates bind-tools libcap; \
    rm -rf /var/cache/apk/*;

COPY --from=gobuild /go/src/github.com/cloudflare/cloudflared/cmd/cloudflared/cloudflared /usr/local/bin/cloudflared

RUN setcap CAP_NET_BIND_SERVICE+eip /usr/local/bin/cloudflared

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s CMD nslookup -po=${PORT} cloudflare.com 127.0.0.1 || exit 1

USER cloudflared

CMD ["/bin/sh", "-c", "/usr/local/bin/cloudflared proxy-dns --address 0.0.0.0 --port ${PORT} --upstream ${UPSTREAM1} --upstream ${UPSTREAM2}"]
