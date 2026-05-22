# Build dochauser index JSON with proper escaping (text, quotes, newlines, umlauts).
build_thumbnails_json() {
  local search_base="$1"
  local output_dir="$2"
  local thumbs_json='[]'
  local jpgfile

  for jpgfile in "${search_base}"*.jpg; do
    [ -f "$jpgfile" ] || continue
    thumbs_json=$(jq -n \
      --argjson prev "$thumbs_json" \
      --arg img "${jpgfile##*/}" \
      --arg dir "/$output_dir" \
      '$prev + [{imgname: $img, imgdirectory: $dir}]')
  done

  printf '%s' "$thumbs_json"
}

write_dochauser_document_json() {
  local json_path="$1"
  local txt_path="$2"
  local uuid="$3"
  local name="$4"
  local directory="$5"
  local timestamp="$6"
  local origin="$7"
  local tagname="$8"
  local search_base="$9"

  local text thumbs_json
  text=$(normalize_pdf_text_from_file "$txt_path")
  thumbs_json=$(build_thumbnails_json "$search_base" "$directory")

  jq -n \
    --arg id "$uuid" \
    --arg name "$name" \
    --arg directory "$directory" \
    --arg text "$text" \
    --arg timestamp "$timestamp" \
    --arg origin "$origin" \
    --arg tagname "$tagname" \
    --argjson thumbnails "$thumbs_json" \
    '{
      id: $id,
      name: $name,
      directory: $directory,
      text: $text,
      timestamp: $timestamp,
      origin: $origin,
      thumbnails: $thumbnails,
      tags: [{tagname: $tagname}]
    }' > "$json_path"
}
