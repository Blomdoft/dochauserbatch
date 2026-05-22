# Sets YEAR, MONTH, DAY, HOUR, MINUTE, SECOND.
# Usage: set_archive_date_from_pdf FILE [metadata|mtime]
#   metadata — PDF CreationDate, then file mtime (imports)
#   mtime    — file modification time only (scans)
set_archive_date_from_pdf() {
  local entry="$1"
  local mode="${2:-metadata}"
  local iso normalized

  iso=""
  if [ "$mode" = "metadata" ]; then
    iso=$(pdfinfo "$entry" -isodates 2>/dev/null | grep -E '^CreationDate:' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}' | head -1)
  fi

  normalized=""
  if [ -n "$iso" ]; then
    normalized=$(date -d "$iso" +%Y-%m-%dT%H:%M:%S 2>/dev/null) || \
      normalized=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%Y-%m-%dT%H:%M:%S 2>/dev/null)
  fi

  if [ -z "$normalized" ]; then
    normalized=$(date -r "$entry" +%Y-%m-%dT%H:%M:%S 2>/dev/null) || \
      normalized=$(stat -c %y "$entry" 2>/dev/null | cut -d. -f1 | tr ' ' T)
  fi

  if [ -z "$normalized" ]; then
    echo "Error: Could not determine date for $entry" >&2
    return 1
  fi

  YEAR=${normalized:0:4}
  MONTH=${normalized:5:2}
  DAY=${normalized:8:2}
  HOUR=${normalized:11:2}
  MINUTE=${normalized:14:2}
  SECOND=${normalized:17:2}
}
