#!/bin/bash

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
source "$CURRENT_DIR/../config/config.sh"

APIKEY_FILE="$CURRENT_DIR/../config/apikey.sh"
if [ -f "$APIKEY_FILE" ]; then
  # shellcheck source=/dev/null
  source "$APIKEY_FILE"
fi

# Normalize model output (strip fences / prose) and validate required analysis fields.
# Prints compact JSON on stdout; returns non-zero on failure.
parse_analysis_json() {
  local raw="$1"
  local candidate

  candidate=$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [[ "$candidate" == *'```'* ]]; then
    candidate=$(printf '%s\n' "$candidate" | sed -e '1s/^```[a-zA-Z]*[[:space:]]*//' -e '$s/[[:space:]]*```[[:space:]]*$//' -e '/^```$/d')
    candidate=$(printf '%s' "$candidate" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  fi

  if ! printf '%s' "$candidate" | jq -e . >/dev/null 2>&1; then
    candidate=$(printf '%s' "$candidate" | jq -Rs 'capture("(?s)(\\{.*\\})") | .[0] // empty' 2>/dev/null)
  fi

  if [ -z "$candidate" ]; then
    return 1
  fi

  printf '%s' "$candidate" | jq -ec '
    if type != "object" then
      error("analysis must be a JSON object")
    else . end |
    def req($name):
      if (.[ $name ] | type) != "string" or .[ $name ] == "" then
        error("missing or empty field: " + $name)
      else . end;
    req("senderAddress") |
    req("receiverAddress") |
    req("intent") |
    req("filename") |
    req("category_level1") |
    req("category_level2")
  '
}

{ 
  if [ -z "$OPENAI_API_KEY" ]; then
    echo "Info: OPENAI_API_KEY is not set; API requests will be sent without authorization."
  fi

  # Elasticsearch server details
  INDEX_NAME="dochauser"
  ES_URL="http://$ES_HOST:9200/$INDEX_NAME/_search"
  UPDATE_URL="http://$ES_HOST:9200/$INDEX_NAME/_doc"
  # Read the system role message from the file
  SYSTEM_ROLE_MESSAGE=$(<"$CURRENT_DIR/../config/prompt_message.txt")

  # Get the date 30 days ago in the format required by Elasticsearch
  DATE_30_DAYS_AGO=$(date -u -v-30d +"%Y%m%dT%H%M%S.000Z" 2>/dev/null || date -u -d '30 days ago' +"%Y%m%dT%H%M%S.000Z" 2>/dev/null)

  # Elasticsearch query to get the first document without analysis
  QUERY='{
    "size": 300,
    "query": {
      "bool": {
        "must": {
          "range": {
            "timestamp": {
              "gte": "'$DATE_30_DAYS_AGO'"
            }
          }
        },
        "must_not": {
          "exists": {
            "field": "analysis"
          }
        }
      }
    }
  }'
  # Fetch documents from Elasticsearch
  RESPONSE=$(curl -s -X GET "$ES_URL" -H 'Content-Type: application/json' -d "$QUERY")

  # Process each document
  echo "$RESPONSE" | jq -c '.hits.hits[]' | while read -r line; do
    ID=$(echo "$line" | jq -r '._id')
    TEXT=$(echo "$line" | jq -r '._source.text')

    echo "Analyzing with GPT....  ${ID}"

      # Prepare the data for the API request
      API_DATA=$(jq -n \
              --arg text "$TEXT" \
              --arg system_msg "$SYSTEM_ROLE_MESSAGE" \
              --arg model "$API_MODEL" \
              --argjson temperature "${API_TEMPERATURE:-0}" \
              '{
                  model: $model,
                  temperature: $temperature,
                  messages: [
                  {"role": "system", "content": $system_msg},
                  {"role": "user", "content": $text}
                  ],
                  response_format: { "type": "json_object" }
              }')

      CURL_AUTH=()
      if [ -n "$OPENAI_API_KEY" ]; then
        CURL_AUTH=(-H "Authorization: Bearer $OPENAI_API_KEY")
      fi

      API_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_ENDPOINT" \
                  -H "Content-Type: application/json" \
                  "${CURL_AUTH[@]}" \
                  -d "$API_DATA")
      HTTP_CODE=$(printf '%s' "$API_RESPONSE" | tail -n1)
      API_BODY=$(printf '%s' "$API_RESPONSE" | sed '$d')

      if [ "$HTTP_CODE" != "200" ]; then
        API_ERROR=$(printf '%s' "$API_BODY" | jq -r '.error.message // .error // .message // .' 2>/dev/null || printf '%s' "$API_BODY")
        echo "Error: API returned HTTP $HTTP_CODE for $ID: $API_ERROR"
        continue
      fi

      ANALYSIS_RAW=$(printf '%s' "$API_BODY" | jq -r '.choices[0].message.content // empty')
      if [ -z "$ANALYSIS_RAW" ] || [ "$ANALYSIS_RAW" = "null" ]; then
        echo "Error: No message content in API response for $ID"
        continue
      fi

      PARSE_ERR_FILE=$(mktemp)
      if ! ANALYSIS_JSON=$(parse_analysis_json "$ANALYSIS_RAW" 2>"$PARSE_ERR_FILE"); then
        echo "Error: Invalid analysis JSON for $ID: $(<"$PARSE_ERR_FILE")"
        rm -f "$PARSE_ERR_FILE"
        echo "Raw response: $ANALYSIS_RAW"
        continue
      fi
      rm -f "$PARSE_ERR_FILE"

      echo "GPT Response validated for $ID"

      UPDATE_BODY=$(jq -n --argjson analysis "$ANALYSIS_JSON" '{doc: {analysis: $analysis}}')
      ES_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$UPDATE_URL/$ID/_update" \
        -H 'Content-Type: application/json' \
        -d "$UPDATE_BODY")
      ES_HTTP_CODE=$(printf '%s' "$ES_RESPONSE" | tail -n1)
      ES_BODY=$(printf '%s' "$ES_RESPONSE" | sed '$d')

      if [ "$ES_HTTP_CODE" != "200" ]; then
        echo "Error: Elasticsearch update failed for $ID (HTTP $ES_HTTP_CODE): $ES_BODY"
        continue
      fi

      echo "Updated analysis for $ID"

  done
} >> "$LOG_FILE"
