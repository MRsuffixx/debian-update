#!/usr/bin/env bash
# Debian Upgrade Manager - controlled, sequential Debian release upgrades.
# Project: https://github.com/MRsuffixx/debian-update
# SPDX-License-Identifier: MIT
# Note: Configuration backups are NOT disk snapshots or a full rollback mechanism.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly APP='Debian Upgrade Manager'
readonly APP_VERSION='3.0.0'
readonly PROJECT='https://github.com/MRsuffixx/debian-update'
readonly STATE_DIR='/var/lib/debian-upgrade-manager'
readonly STATE_FILE="$STATE_DIR/current.state"
readonly BACKUP_ROOT='/var/backups/debian-upgrade-manager'
readonly LOG_ROOT='/var/log/debian-upgrade-manager'
readonly LOCK_FILE='/run/lock/debian-upgrade-manager.lock'

ACTION='menu'
TARGET_REQUESTED=''
NON_INTERACTIVE=0
YES=0
ACCEPT_RISK=0
ALLOW_SSH=0
ALLOW_HOLDS=0
ALLOW_PINNING=0
ALLOW_REMOVALS=0
AUTO_CLEAN=0
RESUME=0
NO_COLOR=0
MAX_REMOVALS=10
COMPONENTS_REQUESTED=''

CURRENT=''
CURRENT_MAJOR=''
TARGET=''
TARGET_MAJOR=''
ARCH=''
COMPONENTS=''
BACKUP_DIR=''
STAGE=''
START=''
LOG_FILE=''
TEMP_DIR=''
COLOR=0
LOCK_FD=''

if [[ -t 1 && ${NO_COLOR:-0} -eq 0 && -z "${NO_COLOR_ENV:-}" ]]; then COLOR=1; fi
if [[ $COLOR -eq 1 ]]; then
    C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[1;36m'; C_RESET=$'\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_RESET=''
fi

say() {
    local level="$1" color="$2"; shift 2
    printf '%s[%s] [%-5s]%s %s\n' "$color" "$(date '+%F %T')" "$level" "$C_RESET" "$*"
}
info() { say INFO "$C_BLUE" "$*"; }
success() { say OK "$C_GREEN" "$*"; }
warn() { say WARN "$C_YELLOW" "$*"; }
error() { say ERROR "$C_RED" "$*" >&2; }
die() { error "$*"; exit 1; }
section() {
    printf '\n%s════════════════════════════════════════════════════════════%s\n' "$C_CYAN" "$C_RESET"
    printf '%s  %s%s\n' "$C_CYAN" "$*" "$C_RESET"
    printf '%s════════════════════════════════════════════════════════════%s\n' "$C_CYAN" "$C_RESET"
}

usage() {
cat <<'EOF'
Debian Upgrade Manager v3.0.0

Usage:
  sudo bash debian-upgrade.sh                       Interactive menu
  sudo bash debian-upgrade.sh --check               Read-only preflight
  sudo bash debian-upgrade.sh --dry-run             Temporary APT index + simulation
  sudo bash debian-upgrade.sh --upgrade             Guided release upgrade
  sudo bash debian-upgrade.sh --resume              Resume interrupted upgrade
  sudo bash debian-upgrade.sh --backup-only         Save configs/package manifest
  sudo bash debian-upgrade.sh --status              Show saved state
  sudo bash debian-upgrade.sh --restore-sources     Restore repo config (before packages change)
  sudo bash debian-upgrade.sh --cleanup             Preview/execute autoremove

Options:
  --target bookworm|trixie  Select only the NEXT supported release
  --components CSV         Explicit APT components (main,contrib,non-free,non-free-firmware)
  --non-interactive        Never prompt; requires --yes --accept-risk for upgrades
  --yes                    Approve normal confirmation prompts
  --accept-risk            Acknowledge external snapshot/console/recovery requirement
  --allow-ssh              Permit execution over SSH (tmux/screen + console recommended)
  --allow-holds            Continue despite held packages
  --allow-pinning          Continue despite APT preferences/pinning
  --allow-removals         Approve planned removal count up to --max-removals
  --max-removals NUMBER    Maximum allowed noncritical dist-upgrade removals (default: 10)
  --auto-clean             Execute apt-get autoremove + clean after upgrade
  --no-color               Disable ANSI colors
  --version                Show version
  -h, --help               Show help

Supported release transitions: Debian 11 -> 12, Debian 12 -> 13.
No Debian 14/testing, Ubuntu, skipped major versions, containers or unattended reboot.
EOF
}

needs_value() { [[ $# -ge 2 && -n "$2" ]] || die "Argument requires a value: $1"; }
parse_args() {
    while (($#)); do
        case "$1" in
            --check) ACTION='check' ;;
            --dry-run) ACTION='dry-run' ;;
            --upgrade) ACTION='upgrade' ;;
            --resume) ACTION='upgrade'; RESUME=1 ;;
            --backup-only) ACTION='backup' ;;
            --status) ACTION='status' ;;
            --restore-sources) ACTION='restore' ;;
            --cleanup) ACTION='cleanup' ;;
            --target) needs_value "$@"; TARGET_REQUESTED="$2"; shift ;;
            --components) needs_value "$@"; COMPONENTS_REQUESTED="$2"; shift ;;
            --non-interactive) NON_INTERACTIVE=1 ;;
            --yes) YES=1 ;;
            --accept-risk) ACCEPT_RISK=1 ;;
            --allow-ssh) ALLOW_SSH=1 ;;
            --allow-holds) ALLOW_HOLDS=1 ;;
            --allow-pinning) ALLOW_PINNING=1 ;;
            --allow-removals) ALLOW_REMOVALS=1 ;;
            --auto-clean) AUTO_CLEAN=1 ;;
            --max-removals) needs_value "$@"; MAX_REMOVALS="$2"; shift ;;
            --no-color) NO_COLOR=1; COLOR=0
                C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_RESET='' ;;
            --version) printf '%s %s\n' "$APP" "$APP_VERSION"; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown argument: $1. Use --help." ;;
        esac
        shift
    done
    [[ "$MAX_REMOVALS" =~ ^[0-9]+$ ]] || die '--max-removals must be a nonnegative integer'
    if [[ "$ACTION" == menu && ( $NON_INTERACTIVE -eq 1 || $YES -eq 1 ) ]]; then ACTION='upgrade'; fi
}

require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die 'Root required. Use sudo.'; }
require_command() {
    local cmd
    for cmd in "$@"; do command -v "$cmd" >/dev/null 2>&1 || die "Required command missing: $cmd"; done
}

setup_log() {
    require_root
    mkdir -p "$LOG_ROOT" "$STATE_DIR" "$BACKUP_ROOT"
    chmod 0700 "$LOG_ROOT" "$STATE_DIR" "$BACKUP_ROOT"
    LOG_FILE="$LOG_ROOT/$(date '+%Y%m%d-%H%M%S')-$$.log"
    : > "$LOG_FILE"; chmod 0600 "$LOG_FILE"
    # Log both terminal and command output; log may contain confidential APT diagnostics.
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "Log: $LOG_FILE"
}

acquire_lock() {
    require_command flock
    exec {LOCK_FD}>"$LOCK_FILE"
    flock -n "$LOCK_FD" || die 'Another Debian Upgrade Manager instance is running.'
}

on_error() {
    local status="$1" line="$2"
    error "Command failed at line $line (exit $status); stage=${STAGE:-none}."
    if [[ -n "$BACKUP_DIR" ]]; then
        error "Backups: $BACKUP_DIR"
        error 'Do not blindly downgrade package sources after packages were changed.'
    fi
    if [[ -n "$LOG_FILE" ]]; then error "Inspect: $LOG_FILE"; fi
}
on_exit() {
    local status="$?"
    trap - EXIT
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then rm -rf -- "$TEMP_DIR"; fi
    return "$status"
}
trap 'on_error "$?" "$LINENO"' ERR
trap on_exit EXIT
trap 'warn "Interrupted; see state and log."; exit 130' INT
trap 'warn "Terminated; see state and log."; exit 143' TERM

read_os() {
    [[ -r /etc/os-release ]] || die 'Cannot read /etc/os-release.'
    # Debian owns the OS release file; values are interpreted only for release detection.
    local ID='' VERSION_ID='' VERSION_CODENAME=''
    # shellcheck source=/dev/null
    source /etc/os-release
    [[ "$ID" == debian ]] || die "Only Debian is supported (detected: $ID)."
    CURRENT_MAJOR="${VERSION_ID%%.*}"
    CURRENT="${VERSION_CODENAME:-}"
    case "$CURRENT_MAJOR:$CURRENT" in
        11:bullseye|12:bookworm|13:trixie) ;;
        *) die "Unsupported Debian release: VERSION_ID=$VERSION_ID codename=$CURRENT" ;;
    esac
    ARCH="$(dpkg --print-architecture)"
}

choose_target() {
    case "$CURRENT" in
        bullseye) TARGET='bookworm'; TARGET_MAJOR=12 ;;
        bookworm) TARGET='trixie'; TARGET_MAJOR=13 ;;
        trixie)
            [[ -z "$TARGET_REQUESTED" ]] || die 'Debian 13 -> 14/testing is intentionally blocked.'
            TARGET=''; TARGET_MAJOR=''; return 0 ;;
        *) die 'Unsupported source release.' ;;
    esac
    if [[ -n "$TARGET_REQUESTED" && "$TARGET_REQUESTED" != "$TARGET" ]]; then
        die "Unsupported/unsafe target '$TARGET_REQUESTED': only $CURRENT -> $TARGET is allowed."
    fi
}

validate_components() {
    local raw="$1" element
    local -a items=()
    local -A seen=()
    raw="${raw//,/ }"
    local oldifs="$IFS"; IFS=' '
    read -r -a items <<< "$raw"
    IFS="$oldifs"
    COMPONENTS=''
    for element in "${items[@]}"; do
        case "$element" in main|contrib|non-free|non-free-firmware) ;; *) die "Invalid APT component: $element" ;; esac
        if [[ -z "${seen[$element]+set}" ]]; then
            seen["$element"]=1
            COMPONENTS+="${COMPONENTS:+ }$element"
        fi
    done
    [[ " $COMPONENTS " == *' main '* ]] || die "APT components must include 'main'."
}

detect_components() {
    if [[ -n "$COMPONENTS_REQUESTED" ]]; then
        validate_components "$COMPONENTS_REQUESTED"
        return
    fi
    local raw='main non-free-firmware'
    # Preserve optional sections if active source lines / deb822 Components mention them.
    local f line
    shopt -s nullglob
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [[ -f "$f" ]] || continue
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            if [[ "$line" =~ ^[[:space:]]*deb[[:space:]\[] || "$line" =~ ^[[:space:]]*Components: ]]; then
                [[ " $line " =~ (^|[[:space:]])contrib([[:space:]]|$) ]] && raw+=' contrib'
                [[ " $line " =~ (^|[[:space:]])non-free([[:space:]]|$) ]] && raw+=' non-free'
            fi
        done < "$f"
    done
    shopt -u nullglob
    validate_components "$raw"
}

release_notes() {
    case "$TARGET" in
        bookworm) printf 'https://www.debian.org/releases/bookworm/releasenotes\n' ;;
        trixie) printf 'https://www.debian.org/releases/trixie/release-notes/\n' ;;
    esac
}

check_disk() {
    local path free required
    local -a checks=('/' '2048' '/var' '3072')
    if command -v mountpoint >/dev/null && mountpoint -q /boot; then checks+=('/boot' '256'); fi
    local i
    for ((i=0; i<${#checks[@]}; i+=2)); do
        path="${checks[i]}"; required="${checks[i+1]}"
        free="$(df -Pm -- "$path" | awk 'NR==2 {print $4}')"
        [[ "$free" =~ ^[0-9]+$ ]] || die "Could not check free space at $path"
        if ((free < required)); then
            die "Insufficient space on $path: ${free} MiB free; minimum ${required} MiB (heuristic)."
        fi
        success "Disk $path: ${free} MiB available (minimum heuristic ${required} MiB)."
    done
    warn 'Free-space thresholds are heuristics, NOT proof the upgrade will fit.'
}

check_dpkg() {
    local result
    result="$(dpkg --audit 2>&1)" || die "dpkg --audit failed: $result"
    [[ -z "$result" ]] || die "dpkg reports broken/incomplete packages:\n$result"
    success 'dpkg database: no incomplete packages reported.'
}

check_holds() {
    local held
    held="$(apt-mark showhold)" || die 'Cannot inspect held packages.'
    if [[ -n "$held" ]]; then
        warn "Held packages:\n$held"
        ((ALLOW_HOLDS)) || die 'Resolve apt holds or explicitly use --allow-holds.'
    fi
}

check_pinning() {
    local f
    if [[ -s /etc/apt/preferences ]]; then
        ((ALLOW_PINNING)) || die 'APT pinning exists in /etc/apt/preferences; use --allow-pinning only after review.'
        warn 'APT preferences file is active.'
    fi
    shopt -s nullglob
    for f in /etc/apt/preferences.d/*; do
        [[ -f "$f" && -s "$f" ]] || continue
        if [[ "$f" == *.pref || "$f" == *.preferences ]]; then
            ((ALLOW_PINNING)) || die "APT pinning found: $f (use --allow-pinning after review)."
            warn "APT pinning allowed: $f"
        fi
    done
    shopt -u nullglob
}

check_processes() {
    if ps -eo comm= | grep -Eq '^(apt|apt-get|dpkg|unattended-upgr|apt.systemd.daily)$'; then
        die 'APT/dpkg process is currently running. Do not run concurrently.'
    fi
}

check_virtualization() {
    if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --container --quiet; then
        die 'Container detected: major host OS upgrades inside containers are not supported.'
    fi
    if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
        die 'WSL detected: unsupported.'
    fi
}

check_ssh() {
    if [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]]; then
        warn 'Remote SSH session detected. Use tmux/screen and verify VNC/KVM/rescue console access.'
        ((ALLOW_SSH)) || die 'For remote use add --allow-ssh after confirming recovery access.'
    fi
}

check_network() {
    require_command getent
    getent ahosts deb.debian.org >/dev/null || die 'Cannot resolve deb.debian.org (DNS/network).'
    getent ahosts security.debian.org >/dev/null || die 'Cannot resolve security.debian.org (DNS/network).'
    success 'Repository DNS resolution OK (actual downloads are checked by apt-get update).'
}

preflight() {
    local include_network="${1:-1}"
    section 'Preflight / Sistem kontrolleri'
    require_command apt-get apt-mark dpkg dpkg-query tar awk sed grep df sha256sum tee date ps
    read_os
    choose_target
    detect_components
    info "OS: Debian $CURRENT_MAJOR ($CURRENT), arch=$ARCH"
    if [[ -n "$TARGET" ]]; then
        info "Supported target: Debian $TARGET_MAJOR ($TARGET)"
        info "Release notes: $(release_notes)"
    else
        success "Debian $CURRENT_MAJOR is the latest supported stable release; no major upgrade offered."
    fi
    info "Components: $COMPONENTS"
    check_virtualization
    check_processes
    check_dpkg
    check_holds
    check_pinning
    check_disk
    check_ssh
    if ((include_network)); then check_network; fi
    success 'Preflight checks completed.'
}

confirm() {
    local prompt="$1" answer=''
    if ((NON_INTERACTIVE)); then
        ((YES && ACCEPT_RISK)) || die '--non-interactive requires --yes --accept-risk for destructive actions.'
        return 0
    fi
    if ((YES && ACCEPT_RISK)); then return 0; fi
    [[ -r /dev/tty ]] || die 'Interactive confirmation requires a TTY.'
    printf '\n%s%s [e/H]: %s' "$C_YELLOW" "$prompt" "$C_RESET" > /dev/tty
    read -r answer < /dev/tty || die 'Unable to read confirmation.'
    [[ "$answer" == e || "$answer" == E || "$answer" == yes || "$answer" == YES ]] || die 'Cancelled by user.'
}

major_confirmation() {
    section 'Risk acknowledgement / Onay'
    warn 'This may restart services, break SSH access, remove packages or fail to boot.'
    warn 'Configuration archives are NOT full-system backups. Create a provider VM snapshot first.'
    warn 'Ensure tested restore, out-of-band console, adequate downtime and release-notes review.'
    if ((NON_INTERACTIVE)); then
        ((YES && ACCEPT_RISK)) || die 'Automation requires --non-interactive --yes --accept-risk.'
    else
        local typed=''
        printf '\nDebian %s -> %s için YUKSELT yazın: ' "$CURRENT_MAJOR" "$TARGET_MAJOR" > /dev/tty
        read -r typed < /dev/tty || die 'Cannot read terminal.'
        [[ "$typed" == 'YUKSELT' ]] || die 'Confirmation rejected.'
    fi
}

write_state() {
    local stage="$1" tmp
    STAGE="$stage"
    mkdir -p "$STATE_DIR"
    tmp="$(mktemp "$STATE_DIR/.current.state.XXXXXX")"
    {
        printf 'START=%q\n' "$START"
        printf 'TARGET=%q\n' "$TARGET"
        printf 'TARGET_MAJOR=%q\n' "$TARGET_MAJOR"
        printf 'COMPONENTS=%q\n' "$COMPONENTS"
        printf 'BACKUP_DIR=%q\n' "$BACKUP_DIR"
        printf 'STAGE=%q\n' "$STAGE"
    } > "$tmp"
    chmod 0600 "$tmp"
    mv -f -- "$tmp" "$STATE_FILE"
    local step='?'
    case "$STAGE" in
        preparing) step=1 ;; base-updated) step=2 ;; sources-switched) step=3 ;;
        target-index-updated) step=4 ;; minimal-started) step=5 ;;
        minimal-done) step=6 ;; full-started) step=7 ;;
        full-done) step=8 ;; complete) step=9 ;;
    esac
    info "Progress [$step/9] -> $STAGE"
}

load_state() {
    [[ -f "$STATE_FILE" ]] || die "State file not found: $STATE_FILE"
    [[ -O "$STATE_FILE" ]] || die 'State file owner is not current user.'
    # State file is created root-only with mode 0600 by this script.
    # shellcheck source=/dev/null
    source "$STATE_FILE"
    [[ "$TARGET" == bookworm || "$TARGET" == trixie ]] || die 'Invalid target in state.'
    [[ "$STAGE" =~ ^[a-z-]+$ ]] || die 'Invalid stage in state.'
    [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]] || die 'Recorded backup directory missing.'
    [[ "$BACKUP_DIR" == "$BACKUP_ROOT/"* ]] || die 'Invalid backup directory in state.'
}

stage_rank() {
    case "$1" in
        preparing) echo 0 ;; base-updated) echo 1 ;; sources-switched) echo 2 ;;
        target-index-updated) echo 3 ;; minimal-started) echo 4 ;; minimal-done) echo 5 ;;
        full-started) echo 6 ;; full-done) echo 7 ;; complete) echo 8 ;;
        *) die "Unknown upgrade stage: $1" ;;
    esac
}

create_backup() {
    section 'Backup / Yapılandırma yedekleri'
    require_root
    local stamp file
    stamp="$(date -u '+%Y%m%dT%H%M%SZ')-$$"
    BACKUP_DIR="$BACKUP_ROOT/$stamp"
    mkdir -m 0700 -p "$BACKUP_DIR/original-sources"
    if [[ -e /etc/apt/sources.list ]]; then cp -a /etc/apt/sources.list "$BACKUP_DIR/original-sources/"; fi
    if [[ -d /etc/apt/sources.list.d ]]; then cp -a /etc/apt/sources.list.d "$BACKUP_DIR/original-sources/"; fi
    local -a items=()
    for file in etc/apt etc/ssh etc/network etc/systemd/system etc/default/grub \
        etc/fstab etc/hostname etc/hosts etc/resolv.conf etc/nsswitch.conf \
        etc/crypttab etc/mdadm etc/lvm etc/docker etc/containerd \
        var/lib/dpkg/status var/lib/apt/extended_states; do
        [[ -e "/$file" || -L "/$file" ]] && items+=("$file")
    done
    ((${#items[@]})) || die 'No critical configuration files found for backup.'
    tar --create --gzip --file "$BACKUP_DIR/system-config.tar.gz" -C / -- "${items[@]}" \
        || die 'Cannot create configuration archive; aborting.'
    dpkg --get-selections > "$BACKUP_DIR/dpkg-selections.txt"
    # shellcheck disable=SC2016 # dpkg-query format placeholders, not shell variables.
    dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' > "$BACKUP_DIR/packages.tsv"
    apt-mark showmanual > "$BACKUP_DIR/apt-manual.txt"
    apt-mark showauto > "$BACKUP_DIR/apt-auto.txt"
    apt-mark showhold > "$BACKUP_DIR/apt-holds.txt"
    cp -a /etc/os-release "$BACKUP_DIR/os-release" 2>/dev/null || true
    (uname -a; printf '\n'; df -h; printf '\n'; lsblk -f 2>/dev/null || true) > "$BACKUP_DIR/system-info.txt"
    printf '%s\n' "Project: $PROJECT" "Source: ${CURRENT:-unknown}" "Target: ${TARGET:-none}" \
        "Created (UTC): $(date -u -Is)" "Config backup only; not a bootable image." > "$BACKUP_DIR/README.txt"
    (cd "$BACKUP_DIR" && sha256sum system-config.tar.gz packages.tsv dpkg-selections.txt > SHA256SUMS)
    chmod -R go-rwx "$BACKUP_DIR"
    success "Backup created: $BACKUP_DIR"
    warn 'Sensitive files (SSH keys, APT credentials) may be included. Keep archives private and off-host.'
}

source_keyring() {
    if [[ -f /usr/share/keyrings/debian-archive-keyring.pgp ]]; then
        printf '%s\n' '/usr/share/keyrings/debian-archive-keyring.pgp'
    elif [[ -f /usr/share/keyrings/debian-archive-keyring.gpg ]]; then
        printf '%s\n' '/usr/share/keyrings/debian-archive-keyring.gpg'
    else
        die 'Debian archive keyring missing. Install/fix debian-archive-keyring before upgrading.'
    fi
}

write_deb822() {
    local destination="$1" keyring
    keyring="$(source_keyring)"
    cat > "$destination" <<EOF
# Managed by Debian Upgrade Manager $APP_VERSION
# Target Debian $TARGET; custom/third-party sources require manual validation.
Types: deb
URIs: https://deb.debian.org/debian
Suites: $TARGET $TARGET-updates
Components: $COMPONENTS
Signed-By: $keyring

Types: deb
URIs: https://security.debian.org/debian-security
Suites: $TARGET-security
Components: $COMPONENTS
Signed-By: $keyring
EOF
    chmod 0644 "$destination"
}

switch_sources() {
    section 'Repository management / APT depoları'
    [[ -d "$BACKUP_DIR/original-sources" ]] || die 'Missing source backups.'
    local entry
    mkdir -p /etc/apt/sources.list.d "$BACKUP_DIR/disabled-sources"
    shopt -s nullglob
    for entry in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        mv -- "$entry" "$BACKUP_DIR/disabled-sources/$(basename "$entry")"
        warn "Temporarily disabled: $(basename "$entry")"
    done
    shopt -u nullglob
    printf '# Managed by Debian Upgrade Manager. See /etc/apt/sources.list.d/debian.sources\n' > /etc/apt/sources.list
    chmod 0644 /etc/apt/sources.list
    write_deb822 /etc/apt/sources.list.d/debian.sources
    success "Official $TARGET repositories configured; third-party repositories disabled."
    warn 'Vendor repos (Docker, PostgreSQL, panels, cloud agents, etc.) will NOT be automatically re-enabled.'
}

apt_run() {
    local -a opts=(-o 'Acquire::Retries=3' -o 'Dpkg::Use-Pty=0')
    if ((NON_INTERACTIVE)); then
        opts+=(-o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confold')
        DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical \
        APT_LISTCHANGES_FRONTEND=none NEEDRESTART_MODE=a UCF_FORCE_CONFFOLD=1 \
            apt-get "${opts[@]}" "$@"
    else
        apt-get "${opts[@]}" "$@"
    fi
}

simulate_plan() {
    local output="$1" removals=0 pkg
    section 'Upgrade simulation / Paket planı'
    apt_run -s dist-upgrade | tee "$output"
    local -a remove_names=()
    while IFS= read -r pkg; do [[ -n "$pkg" ]] && remove_names+=("$pkg"); done \
        < <(awk '$1=="Remv" {print $2}' "$output")
    removals="${#remove_names[@]}"
    info "Planned package removals: $removals (limit: $MAX_REMOVALS)"
    local protected=''
    for pkg in "${remove_names[@]}"; do
        case "$pkg" in
            apt|dpkg|systemd-sysv|systemd|libc6|openssh-server|init|linux-image-amd64|linux-image-arm64)
                protected+=" $pkg" ;;
        esac
    done
    [[ -z "$protected" ]] || die "Critical package removal requested:$protected. Manual intervention needed."
    ((removals <= MAX_REMOVALS)) || die "Too many removals ($removals > $MAX_REMOVALS); inspect $output."
    if ((removals > 0)); then
        warn "Packages proposed for removal: ${remove_names[*]}"
        if ((NON_INTERACTIVE)); then
            ((ALLOW_REMOVALS)) || die 'Non-interactive package removals require --allow-removals.'
        elif ((ALLOW_REMOVALS == 0)); then
            confirm "Approve removal of $removals noncritical packages listed above?"
        fi
    fi
    success 'Simulation accepted within configured guardrails.'
}

write_report() {
    local path="$BACKUP_DIR/upgrade-report.txt"
    {
        printf 'Debian Upgrade Manager %s\n' "$APP_VERSION"
        printf 'From: %s\nTo: %s\n' "$START" "$TARGET"
        printf 'Finished UTC: %s\n' "$(date -u -Is)"
        printf 'Backup: %s\nLog: %s\n' "$BACKUP_DIR" "$LOG_FILE"
        printf 'Kernel (currently running): %s\n' "$(uname -r)"
        printf 'Reboot recommended: yes (manual)\n'
        printf 'Re-enable third-party repos only after vendor compatibility review.\n'
    } > "$path"
    chmod 0600 "$path"
}

guard_autoremove_plan() {
    local plan="$1" count=0 pkg
    local -a removed=()
    while IFS= read -r pkg; do [[ -n "$pkg" ]] && removed+=("$pkg"); done \
        < <(awk '$1=="Remv" {print $2}' "$plan")
    count="${#removed[@]}"
    info "Autoremove candidates: $count (limit: $MAX_REMOVALS)"
    ((count <= MAX_REMOVALS)) || die "Autoremove would remove $count packages; review $plan."
    for pkg in "${removed[@]}"; do
        case "$pkg" in
            apt|dpkg|systemd|systemd-sysv|openssh-server|openssh-client|init|libc6|\
            linux-image-amd64|linux-image-arm64|cloud-init|grub-pc|grub-efi-amd64|\
            network-manager|ifupdown|systemd-resolved)
                die "Refusing autoremove of critical package: $pkg" ;;
        esac
    done
}

cleanup_after_upgrade() {
    section 'Cleanup / Temizlik'
    local plan="$BACKUP_DIR/autoremove-plan.txt"
    apt_run -s autoremove | tee "$plan"
    if ((AUTO_CLEAN)); then
        guard_autoremove_plan "$plan"
        if ((NON_INTERACTIVE)); then
            ((YES && ACCEPT_RISK)) || die 'Automated cleanup requires --yes --accept-risk.'
        else
            confirm 'Execute the autoremove plan shown above?'
        fi
        apt_run -y autoremove
        apt_run clean
        success 'Autoremove + clean completed.'
    else
        info 'Cleanup plan saved, no packages removed. Use --auto-clean to execute.'
    fi
}

check_final() {
    section 'Post-upgrade verification / Son kontroller'
    local ID='' VERSION_ID='' VERSION_CODENAME=''
    # shellcheck source=/dev/null
    source /etc/os-release
    [[ "$ID" == debian && "$VERSION_CODENAME" == "$TARGET" ]] || \
        die "Upgrade did not produce target OS ($TARGET). Detected: $VERSION_CODENAME."
    check_dpkg
    apt_run check
    if [[ -f /var/run/reboot-required ]]; then warn 'System explicitly requests a reboot.'; fi
    success "Debian $TARGET_MAJOR ($TARGET) detected. Review all services and reboot manually."
}

run_upgrade() {
    require_root
    setup_log
    acquire_lock
    if ((RESUME)); then
        section 'Resume / Yarım kalan işlemi sürdür'
        load_state
        [[ "$STAGE" != complete ]] || die 'State is already complete.'
        local prev="$STAGE"
        read_os
        [[ "$CURRENT" == "$START" || "$CURRENT" == "$TARGET" ]] || die 'OS no longer matches saved state.'
        [[ -z "$TARGET_REQUESTED" || "$TARGET_REQUESTED" == "$TARGET" ]] || die 'Saved target differs from --target.'
        check_virtualization
        check_processes
        check_disk
        check_ssh
        if [[ "$STAGE" != minimal-started && "$STAGE" != full-started ]]; then check_dpkg; fi
        major_confirmation_resume
        info "Resuming stage $prev from backup $BACKUP_DIR"
    else
        [[ ! -f "$STATE_FILE" ]] || {
            load_state
            if [[ "$STAGE" != complete ]]; then
                die "Incomplete upgrade at stage $STAGE; use --resume or --restore-sources (if eligible)."
            fi
            mv "$STATE_FILE" "$STATE_DIR/previous-$(date -u '+%Y%m%dT%H%M%SZ')-$$.state"
        }
        preflight 1
        [[ -n "$TARGET" ]] || die "No supported major upgrade exists for the installed Debian release."
        major_confirmation
        START="$CURRENT"
        create_backup
        write_state preparing
    fi

    [[ -n "$TARGET" ]] || die "No supported major upgrade exists for the installed Debian release."
    if (( $(stage_rank "$STAGE") < 1 )); then
        section 'Current-release package updates / Eski sürüm güncellemesi'
        apt_run update
        apt_run -y upgrade
        write_state base-updated
    fi
    if (( $(stage_rank "$STAGE") < 2 )); then
        switch_sources
        write_state sources-switched
    fi
    if (( $(stage_rank "$STAGE") < 3 )); then
        section 'New-release package index / Yeni sürüm indeksleri'
        apt_run update
        write_state target-index-updated
    fi
    if (( $(stage_rank "$STAGE") < 5 )); then
        simulate_plan "$BACKUP_DIR/pre-minimal-plan.txt"
        write_state minimal-started
        section 'Minimal upgrade / Aşama 1'
        apt_run -y upgrade --without-new-pkgs
        write_state minimal-done
    fi
    if (( $(stage_rank "$STAGE") < 7 )); then
        simulate_plan "$BACKUP_DIR/full-upgrade-plan.txt"
        write_state full-started
        section 'Full upgrade / Aşama 2'
        apt_run -y dist-upgrade
        write_state full-done
    fi
    check_final
    cleanup_after_upgrade
    write_report
    write_state complete
    section 'Completed / Yükseltme tamamlandı'
    success "Debian $START -> $TARGET upgrade completed successfully."
    info "Report: $BACKUP_DIR/upgrade-report.txt"
    info "Log: $LOG_FILE"
    warn 'Manual reboot required after service/SSH checks; no automatic reboot is performed.'
}

major_confirmation_resume() {
    warn 'Resuming can install/remove packages and interrupt services.'
    if ((NON_INTERACTIVE)); then
        ((YES && ACCEPT_RISK)) || die '--resume --non-interactive requires --yes --accept-risk.'
    else
        confirm 'Continue this incomplete upgrade?'
    fi
}

run_backup_only() {
    require_root; setup_log; acquire_lock
    read_os
    START="$CURRENT"
    TARGET="$CURRENT"
    COMPONENTS='main'
    create_backup
    success "Backup-only finished: $BACKUP_DIR"
}

run_dry_run() {
    require_root
    setup_log
    acquire_lock
    [[ ! -f "$STATE_FILE" ]] || {
        load_state
        [[ "$STAGE" == complete ]] || die 'Incomplete state present: use --resume, not dry-run.'
    }
    preflight 1
    [[ -n "$TARGET" ]] || die "No supported major upgrade exists for the installed Debian release."
    section 'Isolated dry-run / Gerçek sistemi değiştirmeyen test'
    TEMP_DIR="$(mktemp -d /tmp/debian-upgrade-dryrun.XXXXXXXX)"
    chmod 0700 "$TEMP_DIR"
    mkdir -p "$TEMP_DIR/lists/partial" "$TEMP_DIR/cache/archives/partial"
    write_deb822 "$TEMP_DIR/debian.sources"
    local -a sandbox_opts=(
        -o "Dir::Etc::sourcelist=$TEMP_DIR/debian.sources"
        -o 'Dir::Etc::sourceparts=-'
        -o "Dir::State::lists=$TEMP_DIR/lists"
        -o "Dir::Cache=$TEMP_DIR/cache"
        -o 'APT::Get::List-Cleanup=0'
        -o 'Acquire::Retries=2'
    )
    info 'Downloading index metadata to a temporary directory only.'
    apt-get "${sandbox_opts[@]}" update
    info 'Simulating target dist-upgrade without modifying installed packages:'
    apt-get "${sandbox_opts[@]}" -s dist-upgrade
    success 'Dry-run completed: /etc/apt and installed packages were not modified.'
    warn 'Simulation can differ from the real upgrade after existing-release updates.'
}

run_check() {
    section "$APP $APP_VERSION"
    preflight 1
    success 'Checks passed. This command did not change sources/packages.'
}

run_status() {
    section "$APP $APP_VERSION - Status"
    read_os
    info "Current system: Debian $CURRENT_MAJOR ($CURRENT)"
    if [[ -f "$STATE_FILE" ]]; then
        # Status is informational; readable only to root if state exists.
        if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
            warn 'Root is required to inspect protected upgrade state.'
        else
            load_state
            info "Last upgrade: $START -> $TARGET"
            info "Stage: $STAGE"
            info "Backup: $BACKUP_DIR"
        fi
    else
        info 'No active state recorded.'
    fi
}

run_restore_sources() {
    require_root; setup_log; acquire_lock; load_state
    local rank
    rank="$(stage_rank "$STAGE")"
    ((rank >= 2 && rank <= 3)) || die \
        'Source restore is permitted only after source change and BEFORE minimal/full package upgrade.'
    [[ -d "$BACKUP_DIR/original-sources" ]] || die 'Source archive missing.'
    section 'Restore original APT sources / Kaynakları geri getir'
    warn 'Restoring source files is not a package downgrade or OS rollback.'
    confirm 'Restore original APT sources from the recorded backup?'
    mkdir -m 0700 -p "$BACKUP_DIR/sources-before-manual-restore"
    if [[ -e /etc/apt/sources.list ]]; then
        mv /etc/apt/sources.list "$BACKUP_DIR/sources-before-manual-restore/"
    fi
    if [[ -d /etc/apt/sources.list.d ]]; then
        mv /etc/apt/sources.list.d "$BACKUP_DIR/sources-before-manual-restore/"
    fi
    if [[ -e "$BACKUP_DIR/original-sources/sources.list" ]]; then
        cp -a "$BACKUP_DIR/original-sources/sources.list" /etc/apt/sources.list
    fi
    if [[ -d "$BACKUP_DIR/original-sources/sources.list.d" ]]; then
        cp -a "$BACKUP_DIR/original-sources/sources.list.d" /etc/apt/sources.list.d
    else
        mkdir -p /etc/apt/sources.list.d
    fi
    mv "$STATE_FILE" "$BACKUP_DIR/cancelled-upgrade.state"
    success 'Source files restored. Run apt-get update and investigate the failure manually.'
}

run_cleanup_standalone() {
    require_root; setup_log; acquire_lock
    check_processes
    check_dpkg
    section 'Standalone cleanup / Bağımsız temizlik'
    local plan
    TEMP_DIR="$(mktemp -d /tmp/debian-cleanup.XXXXXXXX)"
    plan="$TEMP_DIR/autoremove-plan.txt"
    apt_run -s autoremove | tee "$plan"
    guard_autoremove_plan "$plan"
    if ((NON_INTERACTIVE));
    then
        ((YES && ACCEPT_RISK && AUTO_CLEAN)) || die 'Use --non-interactive --yes --accept-risk --auto-clean.'
    else
        confirm 'Apply autoremove + apt cache clean?'
    fi
    apt_run -y autoremove
    apt_run clean
    success 'Standalone cleanup completed.'
}

menu() {
    [[ -t 0 && -t 1 ]] || die 'Interactive terminal missing. Use --check, --dry-run or --upgrade.'
    local choice=''
    while true; do
        section "$APP $APP_VERSION"
        printf '  1) Preflight checks / Sistem kontrolü\n'
        printf '  2) Dry-run / Simülasyon\n'
        printf '  3) Upgrade / Sürüm yükselt\n'
        printf '  4) Backup only / Sadece yedek\n'
        printf '  5) Status / Durum\n'
        printf '  6) Resume / Devam et\n'
        printf '  7) Restore sources / APT depolarını geri yükle\n'
        printf '  8) Cleanup / Temizlik\n'
        printf '  0) Exit / Çıkış\n'
        read -r -p 'Seçiminiz: ' choice
        case "$choice" in
            1) ACTION=check; return ;; 2) ACTION=dry-run; return ;;
            3) ACTION=upgrade; return ;; 4) ACTION=backup; return ;;
            5) ACTION=status; return ;; 6) ACTION=upgrade; RESUME=1; return ;;
            7) ACTION=restore; return ;; 8) ACTION=cleanup; return ;;
            0) exit 0 ;; *) warn 'Invalid menu choice.' ;;
        esac
    done
}

main() {
    parse_args "$@"
    if [[ "$ACTION" == menu ]]; then menu; fi
    case "$ACTION" in
        check) run_check ;; dry-run) run_dry_run ;; upgrade) run_upgrade ;;
        backup) run_backup_only ;; status) run_status ;; restore) run_restore_sources ;;
        cleanup) run_cleanup_standalone ;; *) die "Invalid action: $ACTION" ;;
    esac
}
main "$@"
