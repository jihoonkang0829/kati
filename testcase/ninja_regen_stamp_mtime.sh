#!/bin/sh
#
# Copyright 2026 Google Inc. All rights reserved
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu

log=stderr_log
mk="$@"

touch dep.mk extra.txt
# Set mtime to a future timestamp (later than Kati's process start time).
# Previously, Kati compared file mtime against the generation start time,
# falsely marking files with mtime > gen_time as modified on subsequent runs.
touch -d "2050-01-01 00:00:00" dep.mk extra.txt

cat <<EOF > Makefile
include dep.mk
EXTRA_DEPS := extra.txt
\$(KATI_extra_file_deps \$(EXTRA_DEPS))
all:
	echo foo
EOF

${mk} 2> ${log}
if [ -e ninja.sh ]; then
  ./ninja.sh
fi

# A second run without changes should NOT regenerate, even though the file
# mtimes are in the future relative to when Kati started.
${mk} 2> ${log}
if [ -e ninja.sh ]; then
  if grep -q regenerating ${log}; then
    echo 'Should not be regenerated'
  fi
  ./ninja.sh
fi

# Advancing the mtime of an included makefile should trigger regeneration.
touch -d "2051-01-01 00:00:00" dep.mk

${mk} 2> ${log}
if [ -e ninja.sh ]; then
  if ! grep -q regenerating ${log}; then
    echo 'Should have regenerated due to touched makefile'
  fi
  ./ninja.sh
fi

# Running again without changes should NOT regenerate.
${mk} 2> ${log}
if [ -e ninja.sh ]; then
  if grep -q regenerating ${log}; then
    echo 'Should not be regenerated after makefile regen'
  fi
  ./ninja.sh
fi

# Advancing the mtime of an extra file dependency should trigger regeneration.
touch -d "2051-01-01 00:00:00" extra.txt

${mk} 2> ${log}
if [ -e ninja.sh ]; then
  if ! grep -q regenerating ${log}; then
    echo 'Should have regenerated due to touched extra file dependency'
  fi
  ./ninja.sh
fi

# Running again without changes should NOT regenerate.
${mk} 2> ${log}
if [ -e ninja.sh ]; then
  if grep -q regenerating ${log}; then
    echo 'Should not be regenerated after extra file dep regen'
  fi
  ./ninja.sh
fi
