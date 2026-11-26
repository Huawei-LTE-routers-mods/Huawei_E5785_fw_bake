#!/system/bin/sh

ACTION="$1"
SCRIPT="/system/bin/ciadpi"
PIDFILE="/var/run/byedpi.pid"
LOG_FILE="/var/log/byedpi.log"
LOG_MAX_BYTES=65536
LOG_KEEP_LINES=200
PORT=999
AUTORUN_FILE="/system/etc/autorun.d/byedpi.sh"

mkdir -p /var/run /var/log 2>/dev/null

# LAN address of the router (falls back to the stock default).
LAN_IP="$(ip -4 addr show br0 2>/dev/null | awk '/inet /{split($2, a, "/"); print a[1]; exit}')"
[ -n "$LAN_IP" ] || LAN_IP="192.168.8.1"

# Optimized DPI bypass parameters
ARGS="--transparent --daemon --pidfile $PIDFILE -i $LAN_IP -p $PORT \
-Ku -a3 -An -Kt,h -s0 -o1 -d1 -r1+s -Ar -At -f-1 -As  -Q orig -m 3"

# Use iptables if present, otherwise the bundled xtables-multi.
ipt() {
    if command -v iptables >/dev/null 2>&1; then
        iptables "$@"
    else
        xtables-multi iptables "$@"
    fi
}

# Logging with a size cap (/var/log lives in RAM).
log() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE")" -gt "$LOG_MAX_BYTES" ]; then
        tail -n "$LOG_KEEP_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if iptables rules exist
nat_rule_exists() {
    ipt -t nat -C "$@" >/dev/null 2>&1
}

filter_rule_exists() {
    ipt -t filter -C "$@" >/dev/null 2>&1
}

# Add iptables rules safely
add_rules() {
    log "Adding iptables rules"

    nat_rule_exists PREROUTING -i br0 -p tcp -d "$LAN_IP" --dport 80 -j ACCEPT || {
        ipt -t nat -A PREROUTING -i br0 -p tcp -d "$LAN_IP" --dport 80 -j ACCEPT
        log "Added HTTP whitelist rule"
    }

    nat_rule_exists PREROUTING -i br0 -p tcp -d "$LAN_IP" --dport 443 -j ACCEPT || {
        ipt -t nat -A PREROUTING -i br0 -p tcp -d "$LAN_IP" --dport 443 -j ACCEPT
        log "Added HTTPS whitelist rule"
    }

    nat_rule_exists PREROUTING -i br0 -p tcp --dport 80 -j REDIRECT --to-port "$PORT" || {
        ipt -t nat -A PREROUTING -i br0 -p tcp --dport 80 -j REDIRECT --to-port "$PORT"
        log "Added HTTP redirect rule"
    }

    nat_rule_exists PREROUTING -i br0 -p tcp --dport 443 -j REDIRECT --to-port "$PORT" || {
        ipt -t nat -A PREROUTING -i br0 -p tcp --dport 443 -j REDIRECT --to-port "$PORT"
        log "Added HTTPS redirect rule"
    }

    # QUIC / HTTP3 runs over UDP 443 and would skip ByeDPI entirely.
    # Dropping it makes browsers fall back to TCP, which goes through ByeDPI.
    filter_rule_exists FORWARD -i br0 -p udp --dport 443 -j DROP || {
        ipt -t filter -I FORWARD 1 -i br0 -p udp --dport 443 -j DROP
        log "Added QUIC (UDP 443) block rule"
    }
}

# Remove iptables rules safely
remove_rules() {
    log "Removing iptables rules"

    ipt -t nat -D PREROUTING -i br0 -p tcp -d "$LAN_IP" --dport 80 -j ACCEPT 2>/dev/null && log "Removed HTTP whitelist rule"
    ipt -t nat -D PREROUTING -i br0 -p tcp -d "$LAN_IP" --dport 443 -j ACCEPT 2>/dev/null && log "Removed HTTPS whitelist rule"
    ipt -t nat -D PREROUTING -i br0 -p tcp --dport 80 -j REDIRECT --to-port "$PORT" 2>/dev/null && log "Removed HTTP redirect rule"
    ipt -t nat -D PREROUTING -i br0 -p tcp --dport 443 -j REDIRECT --to-port "$PORT" 2>/dev/null && log "Removed HTTPS redirect rule"
    ipt -t filter -D FORWARD -i br0 -p udp --dport 443 -j DROP 2>/dev/null && log "Removed QUIC block rule"
}

# Start ByeDPI
start_byedpi() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Service already running (PID: $pid)"
            return 0
        else
            log "Stale PID file found. Removing."
            rm -f "$PIDFILE"
        fi
    fi

    [ -x "$SCRIPT" ] || {
        log "Executable not found or not executable: $SCRIPT"
        return 1
    }

    log "Starting ByeDPI service on $LAN_IP:$PORT"
    $SCRIPT $ARGS >> "$LOG_FILE" 2>&1 &

    local timeout=5
    while [ $timeout -gt 0 ]; do
        if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
            add_rules
            log "Service started successfully (PID: $(cat $PIDFILE))"
            return 0
        fi
        sleep 1
        timeout=$((timeout-1))
    done

    log "Service failed to start"
    return 1
}

# Stop ByeDPI
stop_byedpi() {
    if [ ! -f "$PIDFILE" ]; then
        log "No PID file found. Service not running?"
        remove_rules
        return 0
    fi

    pid=$(cat "$PIDFILE")
    if ! kill -0 "$pid" 2>/dev/null; then
        log "PID $pid not running. Cleaning up."
        rm -f "$PIDFILE"
        remove_rules
        return 0
    fi

    log "Stopping service (PID: $pid)"
    kill -15 "$pid" 2>/dev/null

    local timeout=5
    while [ $timeout -gt 0 ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$PIDFILE"
            remove_rules
            log "Service stopped successfully"
            return 0
        fi
        sleep 1
        timeout=$((timeout-1))
    done

    log "Force killing PID $pid"
    kill -9 "$pid" 2>/dev/null
    rm -f "$PIDFILE"
    remove_rules
    return 1
}

# Restart ByeDPI
restart_byedpi() {
    stop_byedpi
    sleep 2
    start_byedpi
}

# Check if ByeDPI is running
is_byedpi_running() {
    [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null
}

is_on_boot() {
    test -f "$AUTORUN_FILE"
}

# autorun.d scripts run before the Huawei services bring up br0, so the boot
# hook waits in the background for the LAN address before starting ByeDPI.
# It prefers the user's copy in /online/scripts (which may have custom ARGS).
write_autorun() {
    cat > "$AUTORUN_FILE" <<'EOF'
#!/bin/sh
# Start ByeDPI at boot (created by the ByeDPI menu script).
(
    i=0
    while [ $i -lt 120 ]; do
        ip -4 addr show br0 2>/dev/null | grep -q "inet " && break
        sleep 1
        i=$((i+1))
    done
    S=/online/scripts/Byedpi.sh
    [ -f "$S" ] || S=/app/hijack/scripts/Byedpi.sh
    /bin/sh "$S" ENABLE >/dev/null 2>&1
) &
EOF
    chmod 755 "$AUTORUN_FILE"
}

boot_enable() {
    mount -o remount,rw /system
    mkdir -p /system/etc/autorun.d
    write_autorun
    mount -o remount,ro /system
}

boot_disable() {
    mount -o remount,rw /system
    rm -f "$AUTORUN_FILE"
    mount -o remount,ro /system
}

# Print service status
get_status() {
    if is_byedpi_running; then
        echo "item:<Enabled>:ENABLED"
        echo "item: Disable:DISABLE"
        echo "item: Restart:RESTART"
        echo "text:Running (PID: $(cat $PIDFILE))"
    else
        echo "item: Enable:ENABLE"
        echo "item:<Disabled>:DISABLED"
        echo "text:Stopped"
    fi

    echo "text:Start on boot"
    if is_on_boot; then
        echo "item:<Yes>:BOOT_ENABLE"
        echo "item: No:BOOT_DISABLE"
    else
        echo "item: Yes:BOOT_ENABLE"
        echo "item:<No>:BOOT_DISABLE"
    fi
}

# === Huawei E5785 Menu Interface ===
case "$ACTION" in
    ""|ENABLED|DISABLED)
        echo "text:ByeDPI DPI Bypass:"
        get_status
        ;;
    ENABLE)
        echo "text:Starting ByeDPI..."
        start_byedpi
        echo "text:ByeDPI Status:"
        get_status
        ;;
    DISABLE)
        echo "text:Stopping ByeDPI..."
        stop_byedpi
        echo "text:ByeDPI Status:"
        get_status
        ;;
    RESTART)
        echo "text:Restarting ByeDPI..."
        restart_byedpi
        echo "text:ByeDPI Status:"
        get_status
        ;;
    BOOT_ENABLE)
        boot_enable
        if is_on_boot; then
            echo "text: Start on boot: on"
        else
            echo "text: Failed"
        fi
        ;;
    BOOT_DISABLE)
        boot_disable
        if is_on_boot; then
            echo "text: Failed"
        else
            echo "text: Start on boot: off"
        fi
        ;;
    *)
        echo "text:Invalid option"
        echo "text:Usage: $0 {ENABLE|DISABLE|RESTART|BOOT_ENABLE|BOOT_DISABLE}"
        ;;
esac
