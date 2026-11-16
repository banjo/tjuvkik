#!/bin/sh
# Prints Tjuvkik rows: PRs waiting for your review, then your own open PRs.
set -eu

fields=repository,number,title,updatedAt,url
reviews=$(gh search prs --review-requested=@me --state=open --json "$fields" --limit 20)
mine=$(gh search prs --author=@me --state=open --json "$fields,isDraft" --limit 20)

jq -n --argjson reviews "$reviews" --argjson mine "$mine" '
  def age: (now - (.updatedAt | fromdateiso8601)) as $s
    | if $s < 3600 then "\($s / 60 | floor)m"
      elif $s < 86400 then "\($s / 3600 | floor)h"
      else "\($s / 86400 | floor)d" end;
  def row($icon; $tone): {
    icon: $icon, title: .title, subtitle: "\(.repository.name) #\(.number)",
    trailing: age, tone: $tone, url: .url
  };
  ($reviews | length) as $n
  | {
      hero: {
        value: "\($n)",
        label: (if $n == 1 then "review requested" else "reviews requested" end),
        tone: (if $n > 0 then "warning" else "success" end)
      },
      rows: (
        [$reviews[] | row("👀"; "warning")]
        + [$mine[] | row(if .isDraft then "📝" else "🔀" end; "muted")]
      )
    }'
