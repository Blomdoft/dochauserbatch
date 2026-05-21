FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

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
        apt-transport-https \
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
    && wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
        | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" \
        > /etc/apt/sources.list.d/elastic-7.x.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends elasticsearch \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

    RUN mkdir -p /var/lib/elasticsearch /var/log/elasticsearch \
    && chown -R elasticsearch:elasticsearch /var/lib/elasticsearch /var/log/elasticsearch /etc/elasticsearch
    
RUN update-rc.d elasticsearch defaults 95 10

WORKDIR /home/scanner

COPY --chown=scanner:scanner . .

# change imagemagick config
ARG imagemagic_config=/etc/ImageMagick-6/policy.xml

RUN if [ -f "$imagemagic_config" ]; then \
      sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/g' "$imagemagic_config"; \
    else \
      echo "did not see file $imagemagic_config"; \
    fi

# volumes
VOLUME /home/scanner/archive
VOLUME /home/scanner/scanner
VOLUME /home/scanner/import

EXPOSE 9200

RUN printf "http.host: 0.0.0.0\nnetwork.host: 0.0.0.0\ndiscovery.type: single-node\n" >> /etc/elasticsearch/elasticsearch.yml

RUN crontab -l 2>/dev/null | { cat; echo "* * * * * timeout 1h flock -n /home/scanner/apps/lock/translateNewFiles.lock su scanner -c /home/scanner/apps/scripts/translateNewFiles.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "* * * * * timeout 1h flock -n /home/scanner/apps/lock/translateUploadedFiles.lock su scanner -c /home/scanner/apps/scripts/translateUploadedFiles.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "0 0 * * 0 timeout 1h flock -n /home/scanner/apps/lock/backupElasticSearchIndex.lock su scanner -c /home/scanner/apps/scripts/backupElasticSearchIndex.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "0 0 * * 0 timeout 1h flock -n /home/scanner/apps/lock/houseKeeping.lock su scanner -c /home/scanner/apps/scripts/houseKeeping.sh"; } | crontab -

RUN crontab -l 2>/dev/null | { cat; echo "*/5 * * * * timeout 1h flock -n /home/scanner/apps/lock/batch5Minutes.lock su scanner -c /home/scanner/apps/scripts/batch5Minutes.sh"; } | crontab -

CMD /home/scanner/apps/scripts/startupServices.sh && cron -f