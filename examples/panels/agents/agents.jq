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

def row: {
  icon,
  title,
  subtitle: "\(.session):\(.tab) · \(.agent)",
  trailing: (if .state == "working" then "working" else (.since | age) end),
  tone: (.state | tone),
  note: .waiting
};

.sessions as $sessions
| [$sessions[] | select(.state == "blocked" or .state == "error" or .state == "done")] as $needYou
| [$sessions[] | select(.state == "working")] as $working
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
      else [$sessions[] | row] end
    ),
    # The most urgent icon and how many need you; while none do, how many work, muted.
    menuBar: (
      if ($needYou | length) > 0 then
        {icon: $needYou[0].icon, text: "\($needYou | length)", tone: ($needYou[0].state | tone), menu: [($needYou + $working)[] | row]}
      elif ($working | length) > 0 then
        {icon: "⏳", text: "\($working | length)", tone: "muted", menu: [$working[] | row]}
      else null end
    )
  }
