FROM fluentd:v1.9-1 AS runtime

USER root
RUN mkdir /var/log/nimbot
COPY conf/fluentd /fluentd/etc
