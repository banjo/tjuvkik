#!/bin/sh
# Sample Slack mentions, to show what a feed panel looks like. Times are kept recent.
ago() { date -u -v-"$1" +%Y-%m-%dT%H:%M:%SZ; }

cat <<JSON
{ "items": [
  { "author": "Sara Lind", "where": "#design", "text": "Can you look at the **new onboarding** before Friday?", "time": "$(ago 4M)", "unread": true },
  { "author": "Deploy bot", "icon": "🚀", "where": "#releases", "text": "**v2.4.0** is live in production", "time": "$(ago 38M)", "unread": true },
  { "author": "Kristian Ek", "where": "DM", "text": "Lunch at 12?", "time": "$(ago 2H)" },
  { "author": "Maja Holm", "where": "#team", "text": "Retro moved to **Thursday 14:00**", "time": "$(ago 1d)" }
], "summary": [{ "value": "2", "label": "unread" }] }
JSON
