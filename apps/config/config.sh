# Where the whole structure is resident
#BASE=/Users/florian/Documents/dochauser_mount
BASE=/home/scanner

# All outputs are stored below this directory
ARCHIVE_DIR=$BASE/archive/

# Where all inputs are to be found
MONITOR_DIR=$BASE/scanner/
IMPORT_DIR=$BASE/import/

CATEGORIZED_DIR=$BASE/archive/categorized/
ES_BACKUP_DIR=$BASE/archive/es_backup
RCLONE_CONFIG=$BASE/apps/config/rclone.conf
LOG_FILE=$BASE/archive/log/dochauser.log

# Signal functionality currently does not exist
SIGNAL_NUMBER=+41445008346
SIGNAL_DIR=$BASE/apps/signal-cli-0.10.3/bin/
SIGNAL_GROUP=dZRhXx+fbwTl9QBkPGWeBkHh4UFtOio5suJZQyQ1O0Y=

#Elastic search server (in same container, should be localhost on server)
#ES_HOST="192.168.2.1000"
ES_HOST="localhost"
# OpenAI API (Ollama: API_ENDPOINT="http://localhost:11434/v1/chat/completions")
API_ENDPOINT="https://api.openai.com/v1/chat/completions"
API_MODEL="gpt-4-1106-preview"
API_TEMPERATURE=0
API_MAX_INPUT_BYTES=8096

# Imported PDFs: 1 = force OCR (fixes broken umlauts from PDF private-use glyphs)
# 0 = --skip-text (faster, keeps embedded text; umlauts may show as   etc.)
OCR_IMPORT_FORCE=1

## ensure log directory
mkdir -p "$(dirname "$LOG_FILE")"