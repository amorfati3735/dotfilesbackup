# Focus Mode Blocklist
<!-- 
  AGENT INSTRUCTIONS:
  This file controls what gets blocked during focus sessions.
  
  ## How to add a website:
  Add a line under "## Blocked Websites" with format: `- domain.com`
  - Use bare domains (no https://, no paths)
  - Add both root and www variants if needed (e.g. x.com and www.x.com)
  - Subdomains are separate entries (e.g. mail.google.com)
  
  ## How to add a blocked term:
  Add a line under "## Blocked Terms" with format: `- keyword`
  - Case-insensitive substring match against window titles
  - If any open window's title contains the term, it gets closed immediately
  - Useful for blocking categories (e.g. "anime") instead of listing every domain
  
  ## How to add an app:
  Add a line under "## Blocked Apps" with format: `- ClassName`
  - The class name is the Hyprland window class (case-insensitive)
  - To find an app's class: run `hyprctl clients -j | jq '.[].class'` while the app is open
  - Common examples: "pcsx2-qt" for PCSX2, "firefox" for Firefox, "kitty" for terminal
  
  ## How to remove:
  Delete the line or comment it out with `<!-- -->`
  
  ## Notes:
  - Changes take effect on next focus session start
  - Websites are blocked via /etc/hosts (requires polkit auth on first session)
  - Apps are detected by the distraction monitor and trigger a nudge notification
-->

## Blocked Websites
- x.com
- www.x.com
- reddit.com
- www.reddit.com

## Blocked Terms
- anime
- manga

## Blocked Apps
- pcsx2-qt
- kitty
- antigravity
