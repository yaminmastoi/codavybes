package main

import (
  "os"
  "os/exec"
  "path/filepath"
)

const defaultURL = "https://vybe-beryl.vercel.app/"

func exists(p string) bool { _, err := os.Stat(p); return err == nil }

func main() {
  url := defaultURL
  if len(os.Args) > 1 && os.Args[1] != "" { url = os.Args[1] }
  if env := os.Getenv("CODAVYBES_URL"); env != "" { url = env }

  pf := os.Getenv("ProgramFiles")
  pfx86 := os.Getenv("ProgramFiles(x86)")
  local := os.Getenv("LOCALAPPDATA")
  candidates := []string{
    filepath.Join(pf, "Microsoft", "Edge", "Application", "msedge.exe"),
    filepath.Join(pfx86, "Microsoft", "Edge", "Application", "msedge.exe"),
    filepath.Join(local, "Microsoft", "Edge", "Application", "msedge.exe"),
    filepath.Join(pf, "Google", "Chrome", "Application", "chrome.exe"),
    filepath.Join(pfx86, "Google", "Chrome", "Application", "chrome.exe"),
    filepath.Join(local, "Google", "Chrome", "Application", "chrome.exe"),
  }
  for _, browser := range candidates {
    if browser != "" && exists(browser) {
      _ = exec.Command(browser, "--app="+url, "--start-maximized").Start()
      return
    }
  }
  _ = exec.Command("rundll32", "url.dll,FileProtocolHandler", url).Start()
}
