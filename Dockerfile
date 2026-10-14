# Splunk Enterprise + Enterprise Security 8.3.0 (image-based)
# Build (from /Users/mac/splunk):
#   docker compose build splunk-enterprise-security
#   # or:
#   docker build -t soc-splunk-es:10.2.1 .
#
# Requires build-context file:
#   ./splunk/splunk-enterprise-security_830.spl
#
ARG SPLUNK_IMAGE_TAG=10.2.1
FROM splunk/splunk:${SPLUNK_IMAGE_TAG}

USER root

COPY config/default/web.conf /tmp/soc-defaults/web.conf
COPY config/default/inputs.conf /tmp/soc-defaults/inputs.conf
COPY scripts/seed-es-apps.sh /sbin/seed-es-apps.sh
COPY scripts/docker-bootstrap.sh /sbin/soc-splunk-bootstrap.sh
COPY splunk/splunk-enterprise-security_830.spl \
     /opt/splunk-packages/splunk-enterprise-security_830.spl

# bootstrap 仅手动执行（加 license）；ES 安装靠 seed-es-apps.sh
RUN chmod 755 /sbin/seed-es-apps.sh /sbin/soc-splunk-bootstrap.sh \
    && test -s /opt/splunk-packages/splunk-enterprise-security_830.spl

# Official splunk-ansible hook: run before splunkd start (works with bind-mounted etc)
ENV SPLUNK_BEFORE_START_CMD_1="/bin/bash /sbin/seed-es-apps.sh" \
    ES_SPL=/opt/splunk-packages/splunk-enterprise-security_830.spl \
    SOC_DEFAULTS_SRC=/tmp/soc-defaults

USER ansible

LABEL org.opencontainers.image.title="soc-splunk-enterprise-security" \
      org.opencontainers.image.description="Splunk Enterprise 10.2.x image with ES 8.3.0 package seeded at start" \
      org.opencontainers.image.version="${SPLUNK_IMAGE_TAG}"
