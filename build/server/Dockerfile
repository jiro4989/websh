FROM nimlang/nim:1.0.6-ubuntu AS builder

COPY nimbot_server /work
RUN cd /work && nimble install -Y


FROM nimlang/nim:1.0.6-ubuntu AS runtime

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -yqq && \
    apt-get install -y tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV TZ=Asia/Tokyo

COPY --from=builder /root/.nimble/bin/nimbot_server /usr/local/bin/nimbot_server
ENTRYPOINT ["/usr/local/bin/nimbot_server"]

