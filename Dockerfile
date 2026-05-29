FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV ES_JAVA_OPTS="-Xms512m -Xmx512m"

RUN groupadd -g 1002 elasticsearch \
    && useradd -rm -d /home/elasticsearch -s /bin/bash -g 1002 -u 1002 elasticsearch \
    && groupadd -g 1001 scanner \
    && useradd -rm -d /home/scanner -s /bin/bash -g 1001 -u 1001 scanner

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        curl \
        gnupg2 \
        ca-certificates \
        uuid \
        uuid-runtime \
        ocrmypdf \
        tesseract-ocr-deu \
        imagemagick \
        cron \
        openjdk-17-jre-headless \
        poppler-utils \
        rclone \
        jq \
        procps \
    && wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
        | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
        > /etc/apt/sources.list.d/elastic-8.x.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends elasticsearch \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
        /var/lib/elasticsearch \
        /var/log/elasticsearch \
        /etc/elasticsearch/jvm.options.d \
    && chown -R elasticsearch:elasticsearch \
        /var/lib/elasticsearch \
        /var/log/elasticsearch \
        /etc/elasticsearch

RUN printf -- "-Xms512m\n-Xmx512m\n" \
    > /etc/elasticsearch/jvm.options.d/heap.options

RUN sed -i '/#----------------------- BEGIN SECURITY AUTO CONFIGURATION -----------------------/,/#----------------------- END SECURITY AUTO CONFIGURATION -------------------------/d' /etc/elasticsearch/elasticsearch.yml \
    && printf "\
network.host: 0.0.0.0\n\
http.host: 0.0.0.0\n\
discovery.type: single-node\n\
xpack.security.enabled: false\n\
xpack.security.enrollment.enabled: false\n\
xpack.security.http.ssl.enabled: false\n\
xpack.security.transport.ssl.enabled: false\n" \
    >> /etc/elasticsearch/elasticsearch.yml

WORKDIR /home/scanner

COPY --chown=scanner:scanner . .

ARG imagemagick_config=/etc/ImageMagick-6/policy.xml

RUN if [ -f "$imagemagick_config" ]; then \
      sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/g' "$imagemagick_config"; \
    else \
      echo "did not see file $imagemagick_config"; \
    fi

RUN mkdir -p /home/scanner/apps/lock \
    && chown -R scanner:scanner /home/scanner/apps

VOLUME /home/scanner/archive
VOLUME /home/scanner/scanner
VOLUME /home/scanner/import
VOLUME /home/scanner/apps/config

EXPOSE 9200

RUN crontab -l 2>/dev/null | { cat; echo "* * * * * timeout 1h flock -n /home/scanner/apps/lock/translateNewFiles.lock su scanner -c /home/scanner/apps/scripts/translateNewFiles.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "* * * * * timeout 1h flock -n /home/scanner/apps/lock/translateUploadedFiles.lock su scanner -c /home/scanner/apps/scripts/translateUploadedFiles.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "0 0 * * 0 timeout 1h flock -n /home/scanner/apps/lock/backupElasticSearchIndex.lock su scanner -c /home/scanner/apps/scripts/backupElasticSearchIndex.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "0 0 * * 0 timeout 1h flock -n /home/scanner/apps/lock/houseKeeping.lock su scanner -c /home/scanner/apps/scripts/houseKeeping.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "*/5 * * * * timeout 1h flock -n /home/scanner/apps/lock/batch5Minutes.lock su scanner -c /home/scanner/apps/scripts/batch5Minutes.sh"; } | crontab -

CMD /home/scanner/apps/scripts/startupServices.sh && cron -f
