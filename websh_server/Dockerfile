FROM nimlang/nim:1.6.2-alpine AS base
WORKDIR /work

FROM base AS builder
COPY . /work
RUN nimble build -Y -d:release

FROM docker:20.10.12-dind-alpine3.15 AS runtime
COPY --from=builder /work/bin/websh_server /app
ENTRYPOINT ["/app"]