# VYBE V9.1 Realtime Hotfix

Fixes the runtime crash:

`cannot add postgres_changes callbacks ... after subscribe()`

## Root cause
`NotificationBell` and `NotificationBridge` were opening Supabase Realtime subscriptions with the same static notification channel topic. In React development/StrictMode, effects can mount/reconnect more than once, making an already-subscribed channel receive another `.on('postgres_changes', ...)` binding.

## Fix
- Each Realtime consumer now receives a unique channel topic.
- All `.on()` bindings are registered before `.subscribe()`.
- Notification Bell and system notification bridge use separate consumer names.
- Subscription cleanup is idempotent.
- Realtime setup failures are caught so a transient channel issue cannot crash the app.
- Commerce capability realtime channel also uses a unique topic to avoid the same class of StrictMode issue.

No SQL migration is required for this hotfix.
