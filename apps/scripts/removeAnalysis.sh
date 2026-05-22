#!/bin/bash

# Elasticsearch server details
ES_HOST="192.168.2.1000"
INDEX_NAME="dochauser"
ES_URL="http://$ES_HOST:9200/$INDEX_NAME/_update_by_query"

# Script to remove the 'analysis' property if it exists
QUERY='{
  "script": {
    "source": "if (ctx._source.containsKey(\"analysis\")) { ctx._source.remove(\"analysis\") }",
    "lang": "painless"
  },
  "query": {
    "match_all": {}
  }
}'

# Send the update request to Elasticsearch
curl -X POST "$ES_URL" -H 'Content-Type: application/json' -d "$QUERY"
