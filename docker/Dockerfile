FROM ubuntu:24.04

ARG VARIANT=base
ARG PIPOWER5=false

RUN apt-get update && apt-get install -y curl sudo

# Copy installer script and framework tools (no network fetch during build)
COPY install_pironman5.sh /tmp/install.sh
COPY tools /tmp/installer-tools

RUN if [ "$PIPOWER5" = "true" ]; then \
        bash /tmp/install.sh --variant "$VARIANT" --container --pipower5; \
    else \
        bash /tmp/install.sh --variant "$VARIANT" --container; \
    fi

RUN rm -rf /tmp/install.sh /tmp/installer-tools

COPY docker/entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 34001
CMD ["/entrypoint.sh"]
