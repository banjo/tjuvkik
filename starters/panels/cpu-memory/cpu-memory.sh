#!/bin/sh
# CPU, memory and load as Tjuvkik stats. Only tools that come with macOS.
set -eu

cpu=$(top -l 2 -n 0 -s 1 | awk '/CPU usage/ { idle = $7 } END { sub("%", "", idle); printf "%.0f", 100 - idle }')
memory=$(memory_pressure | awk -F': ' '/free percentage/ { sub("%", "", $2); print 100 - $2 }')
total=$(( $(sysctl -n hw.memsize) / 1073741824 ))
load=$(sysctl -n vm.loadavg | awk '{ print $2 }')

tone() { if [ "$1" -ge 90 ]; then echo error; elif [ "$1" -ge 75 ]; then echo warning; else echo success; fi; }

printf '{ "stats": [
  { "label": "CPU", "value": %s, "unit": "%%", "tone": "%s", "vs": "in use" },
  { "label": "Memory", "value": %s, "unit": "%%", "delta": "of %s GB", "tone": "%s", "vs": "in use" },
  { "label": "Load", "value": "%s", "vs": "1 minute average" }
] }\n' "$cpu" "$(tone "$cpu")" "$memory" "$total" "$(tone "$memory")" "$load"
