#!/bin/bash
set -euo pipefail

ES_HOST="localhost"
TEMP_INDEX_NAME="dochauser_temp"
ORIGINAL_INDEX_NAME="dochauser"
MAPPING_FILE="../scripts/elasticSearchIndex.json"

NEW_MAPPING_JSON=$(<"$MAPPING_FILE")

echo "Deleting old temp index if present..."
curl -fsS -X DELETE "http://$ES_HOST:9200/$TEMP_INDEX_NAME" || true

echo "Creating temp index with new mapping..."
curl -fsS -X PUT "http://$ES_HOST:9200/$TEMP_INDEX_NAME" \
  -H 'Content-Type: application/json' \
  -d"$NEW_MAPPING_JSON"

echo "Reindexing original to temp..."
curl -fsS -X POST "http://$ES_HOST:9200/_reindex?wait_for_completion=true" \
  -H 'Content-Type: application/json' \
  -d "{
    \"source\": { \"index\": \"$ORIGINAL_INDEX_NAME\" },
    \"dest\": { \"index\": \"$TEMP_INDEX_NAME\" }
  }"

echo "Deleting original index..."
curl -fsS -X DELETE "http://$ES_HOST:9200/$ORIGINAL_INDEX_NAME"

echo "Creating original index with new mapping..."
curl -fsS -X PUT "http://$ES_HOST:9200/$ORIGINAL_INDEX_NAME" \
  -H 'Content-Type: application/json' \
  -d"$NEW_MAPPING_JSON"

echo "Reindexing temp back to original..."
curl -fsS -X POST "http://$ES_HOST:9200/_reindex?wait_for_completion=true" \
  -H 'Content-Type: application/json' \
  -d "{
    \"source\": { \"index\": \"$TEMP_INDEX_NAME\" },
    \"dest\": { \"index\": \"$ORIGINAL_INDEX_NAME\" }
  }"

echo "Deleting temp index..."
curl -fsS -X DELETE "http://$ES_HOST:9200/$TEMP_INDEX_NAME"

echo "Done."
