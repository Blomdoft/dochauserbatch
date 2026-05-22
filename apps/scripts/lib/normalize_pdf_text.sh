# Read extracted PDF text; collapse whitespace, keep UTF-8 letters (incl. umlauts).
normalize_pdf_text_from_file() {
  local txt_file="$1"
  sed -e 's/\r//g' -e 's/[[:space:]]\+/ /g' -e 's/^ //' -e 's/ $//' "$txt_file"
}
