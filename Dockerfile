FROM nimlang/nim:1.6.2-alpine AS base

WORKDIR /work

################################################################################
# builder stages
################################################################################

FROM base AS websh_server_builder
COPY websh_server/ /work
RUN nimble build -Y -d:release

FROM base AS websh_remover_builder
COPY websh_remover/ /work
RUN nimble build -Y -d:release

################################################################################
# runtime stages
################################################################################

FROM alpine:3.12 AS websh_server_runtime
COPY --from=websh_server_builder /work/bin/websh_server /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/websh_server"]

FROM alpine:3.12 AS websh_remover_runtime
COPY --from=websh_remover_builder /work/bin/websh_remover /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/websh_remover"]
