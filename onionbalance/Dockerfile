FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    tor \
    && rm -rf /var/lib/apt/lists/*

# Install onionbalance in a venv to avoid PEP 668 restrictions
RUN python3 -m venv /opt/onionbalance-venv && \
    /opt/onionbalance-venv/bin/pip install --no-cache-dir onionbalance

ENV PATH="/opt/onionbalance-venv/bin:$PATH"

RUN mkdir -p /var/lib/onionbalance /etc/onionbalance

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
