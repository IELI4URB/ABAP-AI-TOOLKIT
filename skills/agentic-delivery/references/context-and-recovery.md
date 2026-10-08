# Context, Phase Control, and Recovery

## Context And Phase Control

- Keep one session focused on one coherent delivery phase. Prefer a handoff after
	foundation, domain validation, integration, background processing, UI, or release
	review instead of carrying every phase in one context.
- When a context meter exists, prepare a handoff around 65-70% usage. Without a
	meter, use these signals: conversation compaction, completion of a major phase,
	repeated debugging history obscuring current evidence, or a new phase owned by a
	different skill or agent.
- The assistant cannot open a new chat. Stop at a stable checkpoint, recommend a
	new session, and provide a copy-ready handoff.
- A handoff must include destination, package, transport, language version/tier,
	approved decisions, active and inactive objects, user-modified files, activation
	and test evidence, exact current failure, rejected hypotheses, remaining work in
	priority order, and the first discriminating next check.
- Carry verified facts into the next session. Reopen a decision only when new
	evidence invalidates it.

## Recovery Budget

- Before a repair, state one falsifiable local hypothesis and one check that can
	disprove it.
- Limit speculative repairs for the same failure to three. After that, instrument
	the exact failure category, step to the owning boundary, or hand over as blocked.
- Preserve user edits and the last known-good activation/test checkpoint.
