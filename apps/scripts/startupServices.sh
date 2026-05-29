#!/usr/bin/env bash
set -e

su elasticsearch -s /bin/bash -c "/usr/share/elasticsearch/bin/elasticsearch" &

