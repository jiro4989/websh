FROM nimlang/nim:1.0.6-ubuntu

RUN nimble install -Y \
           jester \
           karax \
           regex \
           ;

RUN nim --version && \
    nimble --version
