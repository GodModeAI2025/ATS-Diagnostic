# Protected rule-profile persistence

The persistence actor reads/writes a versioned local JSON profile away from the UI actor. Files are written atomically with complete file protection. It validates every rule,64-rule/64MiB limits, duplicate stable identities and schema version. Revision gates prevent stale queued writes from replacing newer snapshots. Invalid profiles do not replace the existing file.

Two native iPad test methods passed: fresh actor reload preserves order/IDs/enabled state/Base64 body/header text; stale revision rejection; duplicate/invalid snapshots leave the valid file readable. Monitor loading/saving and restart UI integration are not connected yet. Current UI still correctly discloses session-only rules.

The monitor integration is now connected. Initial loading gates editing and proxy start. Rule edits/deletion/reorder enqueue coalesced revisioned saves with a system-granted background-write lease; background transition attempts a flush. Failed load/save remains visible and a failed load can be retried. This is best-effort system-granted background time, not guaranteed completion after termination.

The full148-method app suite passed. Four targeted persistence methods passed afterward, including two new monitor-level cases: fresh monitor reload retains the latest edit/disabled state and subsequent deletion, and a blocked destination keeps a visible write error without replacing the blocking file. Native app restart UI verification is in progress. TestFlight53 does not contain this integration.
