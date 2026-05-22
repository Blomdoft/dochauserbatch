#! /usr/bin/env bash

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
source $CURRENT_DIR/../config/config.sh
# shellcheck source=lib/pdf_archive_date.sh
source "$CURRENT_DIR/lib/pdf_archive_date.sh"

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

          # OCR the document
          ocrmypdf --skip-text -l deu "$entry" "$OUTPUT_DIR${entry##*/}"
          # extract all text of the pdf to a text file
          pdf2txt -o "$OUTPUT_DIR${entry##*/}.txt" "$OUTPUT_DIR${entry##*/}"
          # save thumbnails of the pages of the pdf
          convert "$entry" -quality 30 "$OUTPUT_DIR${entry##*/}.jpg"

          ### Produce initial JSON document ###

	        UUID=$(uuid)

          # Strip all double whitespaces and linefeeds from text
          PDFTXT=$(tr -cs  "[:alnum:]" " " < "$OUTPUT_DIR${entry##*/}.txt")
          NAME=${entry##*/}

          # Assemble the thumbnail subjason
          SEARCH="$OUTPUT_DIR${entry##*/}"


	        THUMBNAILS=""
	        SIGNALSENDTHUMBS=""
          for JPGFILE in $SEARCH*.jpg; do
            THUMBNAILS="$THUMBNAILS{\"imgname\" : \"${JPGFILE##*/}\",\"imgdirectory\" : \"/$OUTPUT_DIR\"},"
            SIGNALSENDTHUMBS="$SIGNALSENDTHUMBS$OUTPUT_DIR${JPGFILE##*/} "
          done

          ## strip the last ","
          THUMBNAILS=${THUMBNAILS::${#THUMBNAILS}-1}

	        TIMESTAMP="$YEAR$MONTH${DAY}T$HOUR$MINUTE${SECOND}.000Z"

          JSON="{
                      \"id\" : \"$UUID\",
		      \"name\" : \"$NAME\",
                      \"directory\" : \"$OUTPUT_DIR\",
                      \"text\" : \"$PDFTXT\",
                      \"timestamp\" : \"$TIMESTAMP\",
                      \"origin\" : \"IMPORT\",
                      \"thumbnails\" : [
                        $THUMBNAILS
                      ],
                      \"tags\" : [
                        {
                          \"tagname\" : \"IMPORTED\"
                        }
                      ]
                  }"
          echo "$JSON" > "$OUTPUT_DIR${entry##*/}.json"


      	  ## send the record to elastic search
          curl -H "Content-Type: application/json" -XPOST "http://localhost:9200/dochauser/_doc/$UUID" -d @$OUTPUT_DIR${entry##*/}.json

          ### Mark as processed
          touch "$entry.1"

          ## enough voodoo
      fi
    done

} >> $LOG_FILE;
