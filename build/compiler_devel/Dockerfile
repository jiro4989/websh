FROM ubuntu:19.10

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
            build-essential \
            ca-certificates \
            git \
            && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/nim-lang/Nim && \
    cd Nim && \
    bash build_all.sh

ENV PATH $PWD/Nim/bin:$PATH

RUN nimble install -Y \
           jester \
           karax \
           regex \
           ;

RUN nim --version && \
    nimble --version
