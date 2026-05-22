#!/bin/bash

ES_HOST="192.168.2.1000"
INDEX_NAME="dochauser"

# Elasticsearch query to update category_level1 if it exists and is not 'Andere'
QUERY='{
  "script": {
    "source": "if (ctx._source.containsKey(\"analysis\") && ctx._source.analysis != null && ctx._source.analysis.containsKey(\"category_level1\") && ctx._source.analysis.category_level1 != \"Andere\") { ctx._source.analysis.category_level1 = \"Wientzek\" }",
    "lang": "painless"
  },
  "query": {
    "match_all": {}
  }
}'

# Send the update request to Elasticsearch
curl -X POST "http://$ES_HOST:9200/$INDEX_NAME/_update_by_query" -H 'Content-Type: application/json' -d "$QUERY"
