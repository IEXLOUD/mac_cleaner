#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║           macOS POWER CLEANER v2.0  by IEXLOUD                   ║
# ║     Cleaning · Speed Boost · Optimization · Junk Removal         ║
# ╚══════════════════════════════════════════════════════════════════╝
# Compatible: macOS Ventura (13.x) | Also works on Monterey & Sonoma
# Author: Mac Power Cleaner Script
# Usage: chmod +x mac_cleaner.sh && sudo ./mac_cleaner.sh

# ─────────────────────────── COLORS ────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─────────────────────────── GLOBALS ───────────────────────────────
TOTAL_FREED=0
LOG_FILE="$HOME/Desktop/mac_cleaner_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false
ERRORS=0

# ───────────────────────── HELPER FUNCTIONS ─────────────────────────

banner() {
  clear
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║  🍎  macOS POWER CLEANER  v2.0 by IEXLOUD                ║"
  echo "  ║      Cleaning · Boost · Optimize · Free Up Space         ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

section() {
  echo ""
  echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${BLUE}│  $1${RESET}"
  echo -e "${BOLD}${BLUE}└─────────────────────────────────────────────────┘${RESET}"
  log "=== $1 ==="
}

ok()   { echo -e "  ${GREEN}✔${RESET}  $1"; log "[OK] $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; log "[WARN] $1"; }
info() { echo -e "  ${CYAN}ℹ${RESET}  $1"; log "[INFO] $1"; }
fail() { echo -e "  ${RED}✘${RESET}  $1"; log "[FAIL] $1"; ((ERRORS++)); }
step() { echo -e "  ${MAGENTA}▶${RESET}  $1 ..."; }

# Convert bytes to human-readable
human_readable() {
  local bytes=$1
  if   [ "$bytes" -ge 1073741824 ]; then echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
  elif [ "$bytes" -ge 1048576 ];    then echo "$(echo "scale=2; $bytes/1048576"    | bc) MB"
  elif [ "$bytes" -ge 1024 ];       then echo "$(echo "scale=2; $bytes/1024"        | bc) KB"
  else echo "${bytes} B"
  fi
}

# Get folder size in bytes
folder_size() {
  local path="$1"
  [ -d "$path" ] || { echo 0; return; }
  du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}'
}

# Delete with logging and size tracking
clean_path() {
  local path="$1"
  local label="$2"
  if [ -e "$path" ]; then
    local size
    size=$(folder_size "$path")
    if $DRY_RUN; then
      info "[DRY RUN] Would remove: $path ($(human_readable $size))"
    else
      rm -rf "$path" 2>/dev/null && {
        TOTAL_FREED=$((TOTAL_FREED + size))
        ok "Removed $label ($(human_readable $size))"
      } || fail "Could not remove $label"
    fi
  fi
}

# ─────────────────────────── PREFLIGHT ──────────────────────────────

preflight() {
  banner

  # Check macOS version
  OS_VER=$(sw_vers -productVersion 2>/dev/null)
  echo -e "  ${DIM}System: macOS $OS_VER | $(date)${RESET}"
  echo ""

  # Disk space before
  FREE_BEFORE=$(df -k / | awk 'NR==2{print $4 * 1024}')
  echo -e "  ${WHITE}Free space before:${RESET} ${YELLOW}$(human_readable $FREE_BEFORE)${RESET}"
  echo ""

  # Root check
  if [ "$EUID" -ne 0 ]; then
    warn "Some tasks need sudo. Re-run with: ${BOLD}sudo ./mac_cleaner.sh${RESET}"
    echo ""
  fi

  # Parse args
  for arg in "$@"; do
    [ "$arg" = "--dry-run" ] && DRY_RUN=true && warn "DRY RUN MODE — nothing will be deleted"
  done

  echo -e "  ${DIM}Log: $LOG_FILE${RESET}"
  log "macOS Power Cleaner started. OS: $OS_VER | Free before: $(human_readable $FREE_BEFORE)"
}

# ═══════════════════════════════════════════════════════════════════
#  CLEANING MODULES
# ═══════════════════════════════════════════════════════════════════

# ── 1. USER CACHES ─────────────────────────────────────────────────
clean_user_caches() {
  section "1/10 · User Application Caches"
  local cache_dir="$HOME/Library/Caches"
  if [ -d "$cache_dir" ]; then
    step "Scanning $cache_dir"
    local count=0
    while IFS= read -r -d '' dir; do
      local name
      name=$(basename "$dir")
      clean_path "$dir" "Cache: $name"
      ((count++))
    done < <(find "$cache_dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
    info "Processed $count cache entries"
  else
    warn "User cache directory not found"
  fi
}

# ── 2. SYSTEM CACHES ───────────────────────────────────────────────
clean_system_caches() {
  section "2/10 · System Caches"
  [ "$EUID" -ne 0 ] && { warn "Skipped — requires sudo"; return; }

  local dirs=(
    "/Library/Caches"
    "/System/Library/Caches/com.apple.coresymbolicationd"
    "/private/var/folders"
  )
  for d in "${dirs[@]}"; do
    [ -d "$d" ] && clean_path "$d" "System cache: $(basename $d)"
  done
}

# ── 3. BROWSER CACHES ──────────────────────────────────────────────
clean_browser_caches() {
  section "3/10 · Browser Caches"

  # Safari
  clean_path "$HOME/Library/Caches/com.apple.Safari"              "Safari cache"
  clean_path "$HOME/Library/Safari/LocalStorage"                  "Safari LocalStorage"
  clean_path "$HOME/Library/WebKit/com.apple.Safari"              "Safari WebKit"

  # Chrome
  local chrome_base="$HOME/Library/Application Support/Google/Chrome"
  for profile in Default "Profile 1" "Profile 2" "Profile 3"; do
    clean_path "$chrome_base/$profile/Cache"                       "Chrome ($profile) Cache"
    clean_path "$chrome_base/$profile/Code Cache"                  "Chrome ($profile) Code Cache"
    clean_path "$chrome_base/$profile/GPUCache"                    "Chrome GPU Cache"
  done

  # Firefox
  local ff_base="$HOME/Library/Application Support/Firefox/Profiles"
  if [ -d "$ff_base" ]; then
    for profile_dir in "$ff_base"/*/; do
      clean_path "${profile_dir}cache2"   "Firefox cache2"
      clean_path "${profile_dir}startupCache" "Firefox startupCache"
    done
  fi

  # Brave
  local brave_base="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
  for profile in Default "Profile 1"; do
    clean_path "$brave_base/$profile/Cache"      "Brave ($profile) Cache"
    clean_path "$brave_base/$profile/Code Cache" "Brave Code Cache"
  done

  # Edge
  local edge_base="$HOME/Library/Application Support/Microsoft Edge"
  clean_path "$edge_base/Default/Cache"      "Edge Cache"
  clean_path "$edge_base/Default/Code Cache" "Edge Code Cache"
}

# ── 4. LOGS ────────────────────────────────────────────────────────
clean_logs() {
  section "4/10 · Log Files"

  clean_path "$HOME/Library/Logs"           "User Logs"
  clean_path "/Library/Logs"               "System Logs (requires sudo)"
  clean_path "/var/log"                    "Var Logs (requires sudo)"

  # Crash reports
  clean_path "$HOME/Library/Logs/DiagnosticReports" "User Crash Reports"
  [ "$EUID" -eq 0 ] && clean_path "/Library/Logs/DiagnosticReports" "System Crash Reports"

  # CoreAnalytics
  clean_path "$HOME/Library/Logs/CoreSimulator" "CoreSimulator Logs"
}

# ── 5. TEMP & JUNK FILES ───────────────────────────────────────────
clean_temp() {
  section "5/10 · Temporary & Junk Files"

  # Tmp folders
  clean_path "/tmp"              "System /tmp"
  clean_path "/private/tmp"     "Private tmp"
  clean_path "$TMPDIR"          "User TMPDIR ($TMPDIR)"

  # macOS .DS_Store files
  step "Removing .DS_Store files on Desktop & Home"
  if ! $DRY_RUN; then
    local ds_count
    ds_count=$(find "$HOME" -name ".DS_Store" -type f 2>/dev/null | wc -l | tr -d ' ')
    find "$HOME" -name ".DS_Store" -type f -delete 2>/dev/null
    ok "Removed $ds_count .DS_Store files"
    log "[OK] Removed $ds_count .DS_Store files"
  else
    info "[DRY RUN] Would delete .DS_Store files"
  fi

  # Thumbnail caches
  clean_path "$HOME/Library/Thumbnails" "Thumbnail caches"

  # Spotlight
  step "Clearing Spotlight import cache"
  if ! $DRY_RUN; then
    find /private/var/folders -name "com.apple.Spotlight" -type d -exec rm -rf {} + 2>/dev/null
    ok "Cleared Spotlight import cache"
  fi

  # Old iOS backups warning
  local ios_backup="$HOME/Library/Application Support/MobileSync/Backup"
  if [ -d "$ios_backup" ]; then
    local bk_size
    bk_size=$(folder_size "$ios_backup")
    warn "iOS Backups found: $(human_readable $bk_size) at ~/Library/Application Support/MobileSync/Backup"
    warn "Review in Finder > Manage Backups before deleting manually"
  fi
}

# ── 6. XCODE DERIVED DATA ─────────────────────────────────────────
clean_xcode() {
  section "6/10 · Xcode & Developer Junk"

  clean_path "$HOME/Library/Developer/Xcode/DerivedData"         "Xcode DerivedData"
  clean_path "$HOME/Library/Developer/Xcode/Archives"            "Xcode Archives (review first!)"
  clean_path "$HOME/Library/Developer/Xcode/iOS DeviceSupport"   "iOS DeviceSupport"
  clean_path "$HOME/Library/Developer/CoreSimulator/Caches"      "CoreSimulator Caches"

  # Xcode simulators (unavailable only)
  if command -v xcrun &>/dev/null; then
    step "Deleting unavailable iOS Simulators"
    if ! $DRY_RUN; then
      xcrun simctl delete unavailable 2>/dev/null && ok "Removed unavailable simulators" || warn "simctl not available"
    else
      info "[DRY RUN] Would delete unavailable simulators"
    fi
  fi

  # Homebrew
  if command -v brew &>/dev/null; then
    step "Cleaning Homebrew cache"
    if ! $DRY_RUN; then
      brew cleanup --prune=all -s 2>/dev/null && ok "Homebrew cleanup done" || warn "brew cleanup failed"
    else
      info "[DRY RUN] Would run: brew cleanup --prune=all -s"
    fi
    clean_path "$(brew --cache)" "Homebrew download cache"
  fi

  # npm/yarn/pnpm
  for pkg_mgr in npm yarn pnpm; do
    if command -v $pkg_mgr &>/dev/null; then
      step "Clearing $pkg_mgr cache"
      if ! $DRY_RUN; then
        $pkg_mgr cache clean --force 2>/dev/null && ok "$pkg_mgr cache cleared" || warn "$pkg_mgr cache clean failed"
      else
        info "[DRY RUN] Would clean $pkg_mgr cache"
      fi
    fi
  done

  # pip cache
  if command -v pip3 &>/dev/null; then
    step "Clearing pip3 cache"
    if ! $DRY_RUN; then
      pip3 cache purge 2>/dev/null && ok "pip3 cache cleared"
    fi
  fi
}

# ── 7. MAIL ATTACHMENTS & DOWNLOADS ───────────────────────────────
clean_mail() {
  section "7/10 · Mail & Downloads"

  # Mail attachments cache
  clean_path "$HOME/Library/Mail/V10/MailData/Attachments"       "Mail Attachments cache"
  clean_path "$HOME/Library/Containers/com.apple.mail/Data/Library/Caches" "Mail app caches"

  # Large files in Downloads
  step "Scanning Downloads for large files (>100 MB)"
  local large_count=0
  while IFS= read -r file; do
    local fsize
    fsize=$(du -sk "$file" 2>/dev/null | awk '{print $1 * 1024}')
    warn "Large file: $file ($(human_readable $fsize))"
    ((large_count++))
  done < <(find "$HOME/Downloads" -type f -size +100M 2>/dev/null)
  [ "$large_count" -eq 0 ] && ok "No large files found in Downloads" || info "Found $large_count large file(s) in Downloads — review manually"
}

# ── 8. TRASH & QUARANTINE ──────────────────────────────────────────
clean_trash() {
  section "8/10 · Trash & Quarantine"

  # Empty Trash
  step "Emptying Trash"
  if ! $DRY_RUN; then
    local trash_size
    trash_size=$(folder_size "$HOME/.Trash")
    rm -rf "$HOME/.Trash/"* 2>/dev/null
    TOTAL_FREED=$((TOTAL_FREED + trash_size))
    ok "Trash emptied ($(human_readable $trash_size))"
    log "[OK] Trash emptied: $(human_readable $trash_size)"
  else
    info "[DRY RUN] Would empty Trash"
  fi

  # Clear quarantine database
  step "Clearing quarantine database"
  if ! $DRY_RUN; then
    sqlite3 "$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2" "DELETE FROM LSQuarantineEvent;" 2>/dev/null
    ok "Quarantine database cleared"
  fi
}

# ── 9. MEMORY & SPEED OPTIMIZATIONS ───────────────────────────────
optimize_speed() {
  section "9/10 · Speed & Performance Optimizations"

  # Purge inactive memory
  step "Purging inactive memory"
  if ! $DRY_RUN; then
    if [ "$EUID" -eq 0 ]; then
      purge && ok "Inactive memory purged" || warn "purge failed"
    else
      warn "Memory purge requires sudo — skipping"
    fi
  fi

  # Flush DNS cache
  step "Flushing DNS cache"
  if ! $DRY_RUN; then
    dscacheutil -flushcache 2>/dev/null
    killall -HUP mDNSResponder 2>/dev/null
    ok "DNS cache flushed"
  else
    info "[DRY RUN] Would flush DNS"
  fi

  # Rebuild Spotlight index (optional)
  step "Rebuilding Spotlight index"
  if ! $DRY_RUN && [ "$EUID" -eq 0 ]; then
    mdutil -E / 2>/dev/null && ok "Spotlight index rebuild triggered" || warn "mdutil requires root"
  else
    info "[DRY RUN or no sudo] Skipped Spotlight rebuild"
  fi

  # Launch Services database
  step "Rebuilding Launch Services database"
  if ! $DRY_RUN; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
      -kill -r -domain local -domain system -domain user 2>/dev/null
    ok "Launch Services database rebuilt"
  fi

  # Disable heavy login items note
  info "Tip: Open System Settings > General > Login Items to remove startup apps"

  # Font cache
  step "Clearing font cache"
  if ! $DRY_RUN; then
    atsutil databases -remove 2>/dev/null && ok "Font cache cleared" || warn "Font cache: atsutil not found"
  fi
}

# ── 10. LARGE HIDDEN FILES FINDER ─────────────────────────────────
find_large_hidden() {
  section "10/10 · Large & Hidden Files Scanner"

  echo -e "  ${DIM}Scanning for hidden files/folders > 50 MB in home directory...${RESET}"
  local found=0
  while IFS= read -r item; do
    local name
    name=$(basename "$item")
    local isize
    isize=$(du -sk "$item" 2>/dev/null | awk '{print $1 * 1024}')
    printf "  ${YELLOW}%-60s${RESET} %s\n" "$item" "$(human_readable $isize)"
    log "[LARGE] $item — $(human_readable $isize)"
    ((found++))
  done < <(find "$HOME" -maxdepth 4 \( -name ".*" -o -name "*.log" -o -name "*.tmp" \) -size +50M 2>/dev/null | sort)

  [ "$found" -eq 0 ] && ok "No large hidden files found" || warn "Found $found large/hidden items — review above"

  # Old iCloud downloads
  if [ -d "$HOME/Library/Mobile Documents" ]; then
    local icloud_size
    icloud_size=$(folder_size "$HOME/Library/Mobile Documents")
    info "iCloud local data: $(human_readable $icloud_size) — manage in System Settings > Apple ID > iCloud"
  fi
}

# ═══════════════════════════════════════════════════════════════════
#  SUMMARY REPORT
# ═══════════════════════════════════════════════════════════════════

summary() {
  local FREE_AFTER
  FREE_AFTER=$(df -k / | awk 'NR==2{print $4 * 1024}')

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║              🎉  CLEANING COMPLETE                       ║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}║${RESET}  Space freed (tracked):  ${GREEN}$(human_readable $TOTAL_FREED)${RESET}"
  echo -e "${CYAN}║${RESET}  Free disk after:         ${GREEN}$(human_readable $FREE_AFTER)${RESET}"
  echo -e "${CYAN}║${RESET}  Errors encountered:      ${RED}$ERRORS${RESET}"
  echo -e "${CYAN}║${RESET}  Log saved:               ${DIM}$LOG_FILE${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${BOLD}Recommended next steps:${RESET}"
  echo -e "  ${DIM}• Restart your Mac for full effect${RESET}"
  echo -e "  ${DIM}• Open Activity Monitor to check CPU/RAM usage${RESET}"
  echo -e "  ${DIM}• Run this script weekly for best performance${RESET}"
  echo ""
  log "=== DONE | Freed: $(human_readable $TOTAL_FREED) | Errors: $ERRORS ==="
}

# ═══════════════════════════════════════════════════════════════════
#  INTERACTIVE MENU
# ═══════════════════════════════════════════════════════════════════

interactive_menu() {
  banner
  echo -e "  ${BOLD}Choose an option:${RESET}"
  echo ""
  echo -e "  ${GREEN}[1]${RESET} Full Clean (All 10 modules — recommended)"
  echo -e "  ${YELLOW}[2]${RESET} Quick Clean (Caches + Trash + Temp)"
  echo -e "  ${CYAN}[3]${RESET} Browser Caches only"
  echo -e "  ${MAGENTA}[4]${RESET} Developer Cleanup (Xcode, brew, npm)"
  echo -e "  ${BLUE}[5]${RESET} Speed & Performance Boost only"
  echo -e "  ${RED}[6]${RESET} Find Large Hidden Files"
  echo -e "  ${DIM}[0]${RESET} Exit"
  echo ""
  read -r -p "  Your choice: " CHOICE

  case "$CHOICE" in
    1)
      clean_user_caches
      clean_system_caches
      clean_browser_caches
      clean_logs
      clean_temp
      clean_xcode
      clean_mail
      clean_trash
      optimize_speed
      find_large_hidden
      ;;
    2)
      clean_user_caches
      clean_temp
      clean_trash
      ;;
    3)
      clean_browser_caches
      ;;
    4)
      clean_xcode
      ;;
    5)
      optimize_speed
      ;;
    6)
      find_large_hidden
      ;;
    0)
      echo -e "\n  ${DIM}Exiting. No changes made.${RESET}\n"
      exit 0
      ;;
    *)
      warn "Invalid choice. Running Full Clean..."
      clean_user_caches; clean_system_caches; clean_browser_caches
      clean_logs; clean_temp; clean_xcode; clean_mail
      clean_trash; optimize_speed; find_large_hidden
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════════

main() {
  preflight "$@"

  # Non-interactive mode: pass --all flag
  if [[ "$*" == *"--all"* ]]; then
    clean_user_caches
    clean_system_caches
    clean_browser_caches
    clean_logs
    clean_temp
    clean_xcode
    clean_mail
    clean_trash
    optimize_speed
    find_large_hidden
  else
    interactive_menu
  fi

  summary
}

main "$@"
