FROM alpine:3.12 AS base

RUN apk add --no-cache \
    alpine-sdk

ENV PATH /root/.nimble/bin:$PATH

# install nim (#devel) and nim-tools
RUN mkdir -p /nim && \
    git clone https://github.com/nim-lang/Nim /nim && \
    cd /nim && \
    sh build_all.sh && \
    ln -s `pwd`/bin/nim /bin/nim && \
    nim c koch && \
    ./koch tools && \
    ln -s `pwd`/bin/nimble /bin/nimble && \
    ln -s `pwd`/bin/nimsuggest /bin/nimsuggest

RUN mkdir /work
WORKDIR /work

################################################################################
# builder stages
################################################################################

FROM base AS websh_front_builder
COPY websh_front/ /work
RUN nimble build -Y

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
