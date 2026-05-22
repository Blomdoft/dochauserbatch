#! /usr/bin/env bash

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
source $CURRENT_DIR/../config/config.sh
# shellcheck source=lib/pdf_archive_date.sh
source "$CURRENT_DIR/lib/pdf_archive_date.sh"
# shellcheck source=lib/normalize_pdf_text.sh
source "$CURRENT_DIR/lib/normalize_pdf_text.sh"
# shellcheck source=lib/build_elasticsearch_document.sh
source "$CURRENT_DIR/lib/build_elasticsearch_document.sh"

{
    cur_files=$(ls  ${IMPORT_DIR}*.pdf)

    for entry in $cur_files
    do

      if [ -f "$entry.1" ]; then
        :
      else
          echo "$(date '+%Y-%m-%d %H:%M:%S') Needs to be processed: $entry"

          ### Prepare output folder, which is year/month/day ###

          if ! set_archive_date_from_pdf "$entry"; then
            continue
          fi

          OUTPUT_DIR="$ARCHIVE_DIR$YEAR/$MONTH/$DAY/"

          echo "$OUTPUT_DIR determined ($YEAR-$MONTH-$DAY $HOUR:$MINUTE:$SECOND)"

          if [ ! -d "$OUTPUT_DIR" ]; then
            mkdir -p "$OUTPUT_DIR"
            echo "$(date '+%Y-%m-%d %H:%M:%S') Created new output directory $OUTPUT_DIR"
          fi

          ### Process the file ###

          # OCR: --force-ocr replaces PDF text layers that use private-use glyphs ( instead of ü).
          OCR_ARGS=(--force-ocr -l deu)
          if [ "${OCR_IMPORT_FORCE:-1}" != "1" ]; then
            OCR_ARGS=(--skip-text -l deu)
          fi
          ocrmypdf "${OCR_ARGS[@]}" "$entry" "$OUTPUT_DIR${entry##*/}"
          # extract all text of the pdf to a text file (UTF-8)
          pdf2txt -o "$OUTPUT_DIR${entry##*/}.txt" "$OUTPUT_DIR${entry##*/}"
          # save thumbnails of the pages of the pdf
          convert "$entry" -quality 30 "$OUTPUT_DIR${entry##*/}.jpg"

          ### Produce initial JSON document ###

	        UUID=$(uuid)
          NAME=${entry##*/}
          SEARCH="$OUTPUT_DIR${entry##*/}"
          JSON_FILE="$OUTPUT_DIR${entry##*/}.json"
          TIMESTAMP="$YEAR$MONTH${DAY}T$HOUR$MINUTE${SECOND}.000Z"

          write_dochauser_document_json \
            "$JSON_FILE" \
            "$OUTPUT_DIR${entry##*/}.txt" \
            "$UUID" \
            "$NAME" \
            "$OUTPUT_DIR" \
            "$TIMESTAMP" \
            "IMPORT" \
            "IMPORTED" \
            "$SEARCH"

      	  ## send the record to elastic search
          ES_RESPONSE=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" \
            -XPOST "http://localhost:9200/dochauser/_doc/$UUID" -d @"$JSON_FILE")
          ES_HTTP_CODE=$(printf '%s' "$ES_RESPONSE" | tail -n1)
          if [ "$ES_HTTP_CODE" != "201" ] && [ "$ES_HTTP_CODE" != "200" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') Elasticsearch index failed for $NAME (HTTP $ES_HTTP_CODE): $(printf '%s' "$ES_RESPONSE" | sed '$d')"
            continue
          fi

          ### Mark as processed
          touch "$entry.1"

          ## enough voodoo
      fi
    done

} >> $LOG_FILE;
