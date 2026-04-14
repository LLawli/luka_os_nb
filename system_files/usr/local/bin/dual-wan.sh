#!/bin/bash
set -euo pipefail

CONF="/etc/dual-wan.conf"

if [[ ! -f "$CONF" ]]; then
    echo "Erro: $CONF não encontrado. Execute: ujust setup-dual-wan" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONF"

LOG_TAG="dual-wan"

log() { logger -t "$LOG_TAG" "$*"; echo "$*"; }

is_up() {
    local state
    state=$(ip -br link show "$1" 2>/dev/null | awk '{print $2}')
    [[ "$state" == "UP" ]] && ip -4 addr show "$1" 2>/dev/null | grep -q "inet "
}

get_ip() {
    ip -4 addr show "$1" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1
}

get_net() {
    ip -4 addr show "$1" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1 \
        | python3 -c "import sys,ipaddress; n=ipaddress.ip_interface(sys.stdin.read().strip()); print(n.network)" 2>/dev/null \
        || ip -4 route show dev "$1" | awk '/scope link/ {print $1}' | head -1
}

cleanup() {
    while ip rule del table ethernet 2>/dev/null; do :; done
    while ip rule del table wifi 2>/dev/null; do :; done
    ip route flush table ethernet 2>/dev/null || true
    ip route flush table wifi 2>/dev/null || true
    iptables -t mangle -D OUTPUT -j DUAL_WAN 2>/dev/null || true
    iptables -t mangle -F DUAL_WAN 2>/dev/null || true
    iptables -t mangle -X DUAL_WAN 2>/dev/null || true
}

apply_split() {
    local dl_ip ul_ip dl_net ul_net
    dl_ip=$(get_ip "$DL_IFACE")
    ul_ip=$(get_ip "$UL_IFACE")
    dl_net=$(get_net "$DL_IFACE")
    ul_net=$(get_net "$UL_IFACE")
    log "Modo SPLIT — download=$DL_IFACE ($dl_ip)  upload=$UL_IFACE ($ul_ip)"

    ip route add "$dl_net" dev "$DL_IFACE" src "$dl_ip" table ethernet
    ip route add default   via "$DL_GW"    dev "$DL_IFACE"            table ethernet
    ip route add "$ul_net" dev "$UL_IFACE" src "$ul_ip" table wifi
    ip route add default   via "$UL_GW"    dev "$UL_IFACE"            table wifi

    ip route replace default via "$DL_GW" dev "$DL_IFACE" metric 100
    ip route replace default via "$UL_GW" dev "$UL_IFACE" metric 200

    ip rule add from "$dl_ip" table ethernet priority 100
    ip rule add from "$ul_ip" table wifi     priority 100

    iptables -t mangle -N DUAL_WAN
    iptables -t mangle -A DUAL_WAN -p tcp --dport 22   -j MARK --set-mark 2
    iptables -t mangle -A DUAL_WAN -p tcp --dport 873  -j MARK --set-mark 2
    iptables -t mangle -A DUAL_WAN -p tcp --dport 9418 -j MARK --set-mark 2
    iptables -t mangle -A DUAL_WAN -p tcp --dport 443 \
        -m conntrack --ctdir ORIGINAL \
        -m connbytes --connbytes 5000000: --connbytes-dir original --connbytes-mode bytes \
        -j MARK --set-mark 2
    iptables -t mangle -A DUAL_WAN -p tcp --dport 80 \
        -m conntrack --ctdir ORIGINAL \
        -m connbytes --connbytes 5000000: --connbytes-dir original --connbytes-mode bytes \
        -j MARK --set-mark 2

    ip rule add fwmark 2 table wifi priority 50
    iptables -t mangle -A OUTPUT -j DUAL_WAN
    ip route flush cache
    log "Split routing ativo."
}

apply_failover_dl() {
    log "Modo FAILOVER — só download ($DL_IFACE)"
    ip route replace default via "$DL_GW" dev "$DL_IFACE" metric 100
    ip route flush cache
}

apply_failover_ul() {
    log "Modo FAILOVER — só upload ($UL_IFACE)"
    ip route replace default via "$UL_GW" dev "$UL_IFACE" metric 100
    ip route flush cache
}

# === MAIN ===
cleanup

DL_UP=false; UL_UP=false
is_up "$DL_IFACE" && DL_UP=true
is_up "$UL_IFACE" && UL_UP=true

if $DL_UP && $UL_UP; then
    apply_split
elif $DL_UP; then
    apply_failover_dl
elif $UL_UP; then
    apply_failover_ul
else
    log "NENHUMA interface UP!"
    exit 1
fi
