#!/bin/bash
#
# Throwaway md RAID1 on loop devices, for exercising the widget's states and
# notifications without touching a real array. Everything lives in sparse
# files under $WORK_DIR; "Destroy" puts the system back as it was.
#
# Usage: tools/raid-testbed.sh   (asks for sudo when it needs it)

set -u

MD_NAME="${MD_NAME:-md99}"
MD_DEV="/dev/$MD_NAME"
SYSFS="/sys/block/$MD_NAME/md"
# On disk rather than tmpfs: a resync fills the sparse files.
WORK_DIR="${WORK_DIR:-/var/tmp/kraidmonitor-testbed}"
DISK_COUNT=3          # two active members plus one kept aside for spare/re-add
DISK_SIZE=256M
# Slow enough that Syncing stays visible for a while: 256 MiB at 2 MB/s ≈ 2 min.
DEFAULT_SYNC_LIMIT=2000

if [ -t 1 ]; then
    BOLD='\033[1m'; RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    BOLD=''; RED=''; GREEN=''; YELLOW=''; NC=''
fi

info()  { echo -e "${GREEN}==>${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

for cmd in mdadm losetup truncate; do
    if ! command -v "$cmd" &> /dev/null; then
        error "Required command '$cmd' not found."
        exit 1
    fi
done

disk_file() { echo "$WORK_DIR/disk$1.img"; }

# Loop device backing disk N, or nothing when it is not attached.
loop_of() {
    local file
    file=$(disk_file "$1")
    [ -f "$file" ] || return
    losetup --list --noheadings --output NAME --associated "$file" 2>/dev/null | head -n1
}

array_exists() { [ -d "$SYSFS" ]; }

# True when the array is made of our own loop devices, so a real md99 is
# never touched.
array_is_ours() {
    array_exists || return 1
    local i loop
    for i in $(seq 0 $((DISK_COUNT - 1))); do
        loop=$(loop_of "$i")
        [ -n "$loop" ] && [ -d "$SYSFS/dev-$(basename "$loop")" ] && return 0
    done
    return 1
}

require_ours() {
    if ! array_exists; then
        error "$MD_DEV does not exist. Create it first."
        return 1
    fi
    if ! array_is_ours; then
        error "$MD_DEV exists but is not built from $WORK_DIR — refusing to touch it."
        return 1
    fi
}

sysfs_write() {
    echo "$2" | sudo tee "$SYSFS/$1" > /dev/null
}

show_status() {
    echo
    if ! array_exists; then
        echo -e "${BOLD}$MD_DEV${NC}: not present (widget shows Error, or No array once reselected)"
    else
        local attr
        echo -e "${BOLD}$MD_DEV${NC}"
        for attr in array_state level raid_disks degraded sync_action sync_completed sync_speed sync_speed_max; do
            printf '  %-15s %s\n' "$attr" "$(cat "$SYSFS/$attr" 2>/dev/null || echo '-')"
        done
        echo "  members:"
        local dev
        for dev in "$SYSFS"/dev-*; do
            [ -d "$dev" ] || continue
            printf '    %-10s slot=%-5s %s\n' "${dev##*/dev-}" \
                "$(cat "$dev/slot" 2>/dev/null)" "$(cat "$dev/state" 2>/dev/null)"
        done
    fi
    echo "  backing disks:"
    local i loop
    for i in $(seq 0 $((DISK_COUNT - 1))); do
        loop=$(loop_of "$i")
        printf '    disk%d      %s\n' "$i" "${loop:-(not attached)}"
    done
    echo
}

create_array() {
    if array_exists; then
        error "$MD_DEV already exists."
        return 1
    fi
    mkdir -p "$WORK_DIR"
    local i loops=()
    for i in $(seq 0 $((DISK_COUNT - 1))); do
        truncate -s "$DISK_SIZE" "$(disk_file "$i")"
        if [ -z "$(loop_of "$i")" ]; then
            sudo losetup -f "$(disk_file "$i")" || return 1
        fi
        loops+=("$(loop_of "$i")")
    done
    # --assume-clean skips the initial resync, so the array comes up OK and the
    # first transition you see is the one you trigger.
    info "Creating RAID1 $MD_DEV from ${loops[0]} and ${loops[1]} (${loops[2]} kept aside)"
    sudo mdadm --create "$MD_DEV" --level=1 --raid-devices=2 --metadata=1.2 \
        --assume-clean --run --force "${loops[0]}" "${loops[1]}" || return 1
    sysfs_write sync_speed_max "$DEFAULT_SYNC_LIMIT"
    info "Created. Select '$MD_NAME' in the widget configuration."
    info "Sync speed capped at $DEFAULT_SYNC_LIMIT KB/s so syncs last long enough to watch."
}

# Lists member names (loop0 …) whose state matches the given regex.
members_matching() {
    local dev
    for dev in "$SYSFS"/dev-*; do
        [ -d "$dev" ] || continue
        grep -Eq "$1" "$dev/state" 2>/dev/null && echo "${dev##*/dev-}"
    done
}

pick_one() {
    local prompt=$1; shift
    local choices=("$@")
    if [ ${#choices[@]} -eq 0 ]; then
        return 1
    fi
    if [ ${#choices[@]} -eq 1 ]; then
        echo "${choices[0]}"
        return 0
    fi
    local i
    for i in "${!choices[@]}"; do
        echo "  $((i + 1))) ${choices[$i]}" >&2
    done
    local n
    read -rp "$prompt [1-${#choices[@]}]: " n
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#choices[@]} ]; then
        echo "${choices[$((n - 1))]}"
    else
        return 1
    fi
}

fail_member() {
    require_ours || return 1
    local member
    member=$(pick_one "Member to fail" $(members_matching 'in_sync|spare')) || {
        error "No member to fail."
        return 1
    }
    info "Failing /dev/$member → widget should report Degraded"
    sudo mdadm "$MD_DEV" --fail "/dev/$member"
}

remove_failed() {
    require_ours || return 1
    if [ -z "$(members_matching faulty)" ]; then
        warn "No faulty member to remove."
        return 0
    fi
    info "Removing faulty members"
    sudo mdadm "$MD_DEV" --remove failed
}

# Our attached loop devices that are not currently members of the array.
free_disks() {
    local i loop
    for i in $(seq 0 $((DISK_COUNT - 1))); do
        loop=$(loop_of "$i")
        [ -n "$loop" ] || continue
        [ -d "$SYSFS/dev-$(basename "$loop")" ] || echo "$loop"
    done
}

add_loop() {
    local loop=$1
    # Wiping the old superblock forces a full recovery instead of a quick re-add.
    sudo mdadm --zero-superblock "$loop" 2> /dev/null
    if [ "$(cat "$SYSFS/degraded")" = "0" ]; then
        info "Adding $loop as a spare (array is not degraded) → state unchanged"
    else
        info "Adding $loop → widget should report Syncing (recover), then OK"
    fi
    sudo mdadm "$MD_DEV" --add "$loop"
}

add_disk() {
    require_ours || return 1
    local loop
    loop=$(pick_one "Disk to add" $(free_disks)) || {
        error "No free disk. Fail and remove a member first."
        return 1
    }
    add_loop "$loop"
}

# Undoes "Fail a member": drops the faulty members, then rebuilds onto a free
# disk. md cannot clear the faulty flag in place, so remove + add is the only way.
repair_array() {
    require_ours || return 1
    if [ -n "$(members_matching faulty)" ]; then
        info "Removing faulty members"
        sudo mdadm "$MD_DEV" --remove failed || return 1
    fi
    if [ "$(cat "$SYSFS/degraded")" = "0" ]; then
        info "Array is not degraded — nothing to rebuild."
        return 0
    fi
    if [ "$(cat "$SYSFS/sync_action")" = "recover" ]; then
        info "Already rebuilding onto a spare — nothing to add."
        return 0
    fi
    local loop
    loop=$(free_disks | head -n1)
    if [ -z "$loop" ]; then
        error "No free disk to rebuild onto."
        return 1
    fi
    add_loop "$loop"
}

start_check() {
    require_ours || return 1
    info "Starting a scrub (sync_action=check) → Syncing, then OK"
    sysfs_write sync_action check
}

stop_sync() {
    require_ours || return 1
    info "Interrupting the running sync (sync_action=idle)"
    sysfs_write sync_action idle
}

set_sync_limit() {
    require_ours || return 1
    local limit
    read -rp "Max sync speed in KB/s ('system' for the kernel default) [$DEFAULT_SYNC_LIMIT]: " limit
    sysfs_write sync_speed_max "${limit:-$DEFAULT_SYNC_LIMIT}" && info "sync_speed_max = $(cat "$SYSFS/sync_speed_max")"
}

set_readonly() {
    require_ours || return 1
    info "Switching to read-only → array_state 'readonly', widget should report Error"
    sudo mdadm --readonly "$MD_DEV"
}

set_readwrite() {
    require_ours || return 1
    info "Switching back to read-write → OK"
    sudo mdadm --readwrite "$MD_DEV"
}

stop_array() {
    require_ours || return 1
    info "Stopping $MD_DEV → sysfs entry disappears, widget should report Error"
    sudo mdadm --stop "$MD_DEV"
}

assemble_array() {
    if array_exists; then
        error "$MD_DEV is already running."
        return 1
    fi
    local i loop loops=()
    for i in $(seq 0 $((DISK_COUNT - 1))); do
        loop=$(loop_of "$i")
        [ -n "$loop" ] && loops+=("$loop")
    done
    if [ ${#loops[@]} -eq 0 ]; then
        error "No backing disks attached. Create the array first."
        return 1
    fi
    info "Assembling $MD_DEV from ${loops[*]}"
    sudo mdadm --assemble --run "$MD_DEV" "${loops[@]}" && sysfs_write sync_speed_max "$DEFAULT_SYNC_LIMIT"
}

destroy_all() {
    if array_exists; then
        require_ours || return 1
        info "Stopping $MD_DEV"
        sudo mdadm --stop "$MD_DEV" || return 1
    fi
    local i loop
    for i in $(seq 0 $((DISK_COUNT - 1))); do
        loop=$(loop_of "$i")
        if [ -n "$loop" ]; then
            sudo mdadm --zero-superblock "$loop" 2> /dev/null
            sudo losetup -d "$loop"
            info "Detached $loop"
        fi
    done
    rm -rf "$WORK_DIR"
    info "Test bed removed"
}

menu() {
    echo -e "${BOLD}KRaidMonitor test bed${NC} — $MD_DEV, files in $WORK_DIR"
    echo "   1) Create array (RAID1, 2 disks + 1 aside)"
    echo "   2) Show status"
    echo "   3) Fail a member            → Degraded"
    echo "   4) Repair (undo a failure)  → Syncing (recover) → OK"
    echo "   5) Remove faulty members"
    echo "   6) Add a disk               → Syncing (recover) → OK"
    echo "   7) Start a check (scrub)    → Syncing → OK"
    echo "   8) Interrupt running sync"
    echo "   9) Set sync speed limit"
    echo "  10) Set read-only            → Error"
    echo "  11) Set read-write           → OK"
    echo "  12) Stop array               → Error"
    echo "  13) Assemble array again"
    echo "   d) Destroy everything"
    echo "   q) Quit"
}

while true; do
    menu
    read -rp "Choice: " choice || break
    case "$choice" in
        1) create_array ;;
        2) show_status ;;
        3) fail_member ;;
        4) repair_array ;;
        5) remove_failed ;;
        6) add_disk ;;
        7) start_check ;;
        8) stop_sync ;;
        9) set_sync_limit ;;
        10) set_readonly ;;
        11) set_readwrite ;;
        12) stop_array ;;
        13) assemble_array ;;
        d|D) destroy_all ;;
        q|Q) break ;;
        *) warn "Unknown choice: $choice" ;;
    esac
    echo
done

if array_exists || [ -d "$WORK_DIR" ]; then
    warn "Test bed left in place. Run the script again and choose 'd' to remove it."
fi
