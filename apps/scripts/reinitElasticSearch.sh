#! /usr/bin/env bash

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
source $CURRENT_DIR/../config/config.sh



    # delete the existing index
    # curl -H "Content-Type: application/json" -XDELETE "http://localhost:9200/dochauser"
    # reinit index from file
    curl -H "Content-Type: application/json" -XPUT "http://localhost:9200/dochauser" -d "@$CURRENT_DIR/elasticSearchIndex.json"

    # Fill the index
    cur_files=$(find $ARCHIVE_DIR -name "*.pdf.json")
    for entry in $cur_files
    do
        UUID_LINE=$(grep "\"id\" : \"" $entry | tr -d '":, ')
        UUID=${UUID_LINE:2:36}
        #send the record to elastic search
        curl -H "Content-Type: application/json" -XPOST "http://localhost:9200/dochauser/_doc/$UUID" -d @$entry

    done

