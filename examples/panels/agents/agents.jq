# agent-watcher's sessions as Tjuvkik rows: a count per state that needs you, then every session.

def age:
  if . == null then null
  else (now - .) as $s
    | if $s < 60 then "now"
      elif $s < 3600 then "\($s / 60 | floor)m"
      elif $s < 86400 then "\($s / 3600 | floor)h"
      else "\($s / 86400 | floor)d" end
  end;

def tone: {blocked: "warning", error: "error", done: "info", working: "accent", idle: "muted"}[.] // "normal";

.sessions as $sessions
| {
    summary: [
      ["blocked", "waiting"], ["error", "failed"], ["done", "done"], ["working", "working"]
      | . as [$state, $label]
      | [$sessions[] | select(.state == $state)] as $matching
      | select($matching | length > 0)
      | {icon: $matching[0].icon, value: "\($matching | length)", label: $label, tone: ($state | tone)}
    ],
    rows: (
      if ($sessions | length) == 0 then [{icon: "🤖", title: "No agents running", tone: "muted"}]
      else [
        $sessions[] | {
          icon,
          title,
          subtitle: "\(.session):\(.tab) · \(.agent)",
          trailing: (if .state == "working" then "working" else (.since | age) end),
          tone: (.state | tone),
          note: .waiting
        }
      ] end
    )
  }
