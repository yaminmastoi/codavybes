use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  let mut builder = tauri::Builder::default();

  #[cfg(desktop)]
  {
    builder = builder.plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
      if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
      }
    }));
  }

  builder
    .plugin(tauri_plugin_deep_link::init())
    .plugin(tauri_plugin_opener::init())
    .plugin(tauri_plugin_store::Builder::new().build())
    .plugin(tauri_plugin_notification::init())
    .setup(|app| {
      #[cfg(any(target_os = "windows", target_os = "linux"))]
      {
        use tauri::menu::{Menu, MenuItem};
        use tauri::tray::TrayIconBuilder;
        use tauri_plugin_deep_link::DeepLinkExt;

        app.deep_link().register_all()?;

        let show = MenuItem::with_id(app, "show", "Open CodaVybes", true, None::<&str>)?;
        let quit = MenuItem::with_id(app, "quit", "Quit CodaVybes", true, None::<&str>)?;
        let menu = Menu::with_items(app, &[&show, &quit])?;
        let tray_icon = app.default_window_icon().cloned();
        let mut tray = TrayIconBuilder::with_id("codavybes-tray")
          .tooltip("CodaVybes")
          .menu(&menu)
          .show_menu_on_left_click(false)
          .on_menu_event(|app, event| match event.id().as_ref() {
            "show" => {
              if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.unminimize();
                let _ = window.set_focus();
              }
            }
            "quit" => app.exit(0),
            _ => {}
          });
        if let Some(icon) = tray_icon { tray = tray.icon(icon); }
        let _ = tray.build(app)?;
      }
      Ok(())
    })
    .on_window_event(|window, event| {
      #[cfg(any(target_os = "windows", target_os = "linux"))]
      if let tauri::WindowEvent::CloseRequested { api, .. } = event {
        // Keep Realtime/native notification bridges alive when the user closes
        // the app window. The tray menu provides an explicit Quit action.
        api.prevent_close();
        let _ = window.hide();
      }
    })
    .run(tauri::generate_context!())
    .expect("error while running CodaVybes");
}
