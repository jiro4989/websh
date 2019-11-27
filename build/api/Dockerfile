FROM ubuntu:18.04

RUN apt-get update -yqq \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       build-essential \
       git \
       ;

ENV PATH /root/.nimble/bin:$PATH
RUN curl https://nim-lang.org/choosenim/init.sh -sSf > init.sh
RUN sh init.sh -y \
    && choosenim update stable
