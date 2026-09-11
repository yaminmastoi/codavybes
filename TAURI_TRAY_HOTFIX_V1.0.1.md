# CodaVybes V1.0.1 Tauri Tray Hotfix

Fixes Windows/Linux CI error:

`unresolved import tauri::tray`

Cause: Tauri v2 gates `tauri::tray` behind the `tray-icon` Cargo feature.

Applied change in `platforms/desktop-tauri/src-tauri/Cargo.toml`:

```toml
tauri = { version = "2", features = ["tray-icon"] }
```

No change is required in `src/lib.rs` for this compiler error.
