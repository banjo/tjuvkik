#!/bin/sh
# The battery's charge as a Tjuvkik meter. Prints an error on a Mac without a battery.
set -eu

line=$(pmset -g batt | grep InternalBattery || true)
if [ -z "$line" ]; then
  echo "this Mac has no battery" >&2
  exit 1
fi
percent=$(echo "$line" | sed -E 's/.*[[:space:]]([0-9]+)%.*/\1/')
state=$(echo "$line" | awk -F'; ' '{ print $2 }')
remaining=$(echo "$line" | grep -oE '[0-9]+:[0-9]{2} remaining' | cut -d' ' -f1 | grep -v '^0:00$' || true)

if [ "$percent" -le 10 ]; then tone=error; elif [ "$percent" -le 20 ]; then tone=warning; else tone=success; fi
case "$state" in
  charging) footer="Charging${remaining:+, $remaining until full}" ;;
  charged|finishing\ charge) footer="Charged" ;;
  AC\ attached) footer="Plugged in, not charging" ;;
  *) footer="On battery${remaining:+, $remaining left}" ;;
esac

printf '{ "meters": { "label": "Battery", "value": %s, "tone": "%s" }, "footer": "%s", "summary": [{ "value": "%s%%" }] }\n' "$percent" "$tone" "$footer" "$percent"
