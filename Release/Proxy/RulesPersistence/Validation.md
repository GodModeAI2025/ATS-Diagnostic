# Protected rule-profile persistence

The persistence actor reads/writes a versioned local JSON profile away from the UI actor. Files are written atomically with complete file protection. It validates every rule,64-rule/64MiB limits, duplicate stable identities and schema version. Revision gates prevent stale queued writes from replacing newer snapshots. Invalid profiles do not replace the existing file.

Two native iPad test methods passed: fresh actor reload preserves order/IDs/enabled state/Base64 body/header text; stale revision rejection; duplicate/invalid snapshots leave the valid file readable. Monitor loading/saving and restart UI integration are not connected yet. Current UI still correctly discloses session-only rules.
