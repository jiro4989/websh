FROM docker:19.03-dind AS base

# Let's start with some basic stuff.
RUN apk add --no-cache alpine-sdk
RUN mkdir -p /nim && \
    curl -sL "http://nim-lang.org/download/nim-1.0.6.tar.xz" | tar xJ --strip-components=1 -C /nim && \
    cd /nim && \
    sh build.sh && \
    rm -r c_code tests

ENV PATH=/nim/bin:/root/.nimble/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /nim
RUN nim c -d:release koch.nim && \
    ./koch nimble

RUN nim --version && \
    nimble --version


FROM base AS builder

COPY nimbot_executor /work
RUN cd /work && nimble install -Y


FROM docker:19.03-dind AS runtime

RUN apk add --update --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone && \
    apk del tzdata

COPY --from=builder /root/.nimble/bin/nimbot_executor /usr/local/bin/nimbot_executor
ENTRYPOINT ["/usr/local/bin/nimbot_executor"]
