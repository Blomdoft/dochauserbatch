#!/bin/bash

ES_HOST="192.168.2.1000"
TEMP_INDEX_NAME="dochauser_temp"
ORIGINAL_INDEX_NAME="dochauser"
MAPPING_FILE="elasticSearchIndex.json"

NEW_MAPPING_JSON=$(<"$MAPPING_FILE")

# Step 0: Update the index template on the temp index
echo "Updating the index template for $TEMP_INDEX_NAME..."
curl -X PUT "http://$ES_HOST:9200/_template/$TEMP_INDEX_NAME" -H 'Content-Type: application/json' -d"$NEW_MAPPING_JSON"


# Step 1: Reindex data from original to temporary index
echo "Reindexing data from $ORIGINAL_INDEX_NAME to $TEMP_INDEX_NAME..."
curl -X POST "http://$ES_HOST:9200/_reindex" -H 'Content-Type: application/json' -d'
{
  "source": {
    "index": "'$ORIGINAL_INDEX_NAME'"
  },
  "dest": {
    "index": "'$TEMP_INDEX_NAME'"
  }
}'

# Step 2: Delete the original index
echo "Deleting the original index $ORIGINAL_INDEX_NAME..."
curl -X DELETE "http://$ES_HOST:9200/$ORIGINAL_INDEX_NAME"

# Step 3: Update the index template
echo "Updating the index template for $ORIGINAL_INDEX_NAME..."
curl -X PUT "http://$ES_HOST:9200/_template/$ORIGINAL_INDEX_NAME" -H 'Content-Type: application/json' -d"$NEW_MAPPING_JSON"

# Step 4: Reindex data back to the original index name
#echo "Reindexing data back to $ORIGINAL_INDEX_NAME..."
curl -X POST "http://$ES_HOST:9200/_reindex" -H 'Content-Type: application/json' -d'
{
  "source": {
    "index": "'$TEMP_INDEX_NAME'"
  },
  "dest": {
    "index": "'$ORIGINAL_INDEX_NAME'"
  }
}'

# Optional Step 5: Delete the temporary index
#echo "Deleting the temporary index $TEMP_INDEX_NAME..."
#curl -X DELETE "http://$ES_HOST:9200/$TEMP_INDEX_NAME"
