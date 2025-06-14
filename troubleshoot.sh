#!/bin/bash
# Troubleshooting script for HAProxy IPv6 DEMUX
# This script gathers system information, docker status and
# tests connectivity to help diagnose issues when the relay
# server cannot be reached.

set -euo pipefail

REPORT="troubleshoot_report_$(date +%Y%m%d_%H%M%S).txt"

CONFIG_ENV="config.env"
HAPROXY_CFG="haproxy/haproxy.cfg"

# Helper to read variables from config.env
read_env_var() {
    local var="$1"
    grep -E "^${var}=" "$CONFIG_ENV" | cut -d= -f2-
}

SUBNET="$(read_env_var SUBNET || true)"
IPV4_ADDRESS="$(read_env_var IPV4_ADDRESS || true)"

{
    echo "======= System Information ======="
    uname -a
    echo

    echo "======= IP Addresses ======="
    ip addr
    echo

    echo "======= Routing Table ======="
    ip route
    ip -6 route
    echo

    echo "======= Docker Containers ======="
    docker compose ps
    docker ps
    echo

    echo "======= HAProxy Configuration ======="
    if [ -f "$HAPROXY_CFG" ]; then
        cat "$HAPROXY_CFG"
    else
        echo "No HAProxy configuration found at $HAPROXY_CFG"
    fi
    echo

    echo "======= HAProxy Configuration Check ======="
    docker compose exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg || true
    echo

    echo "======= HAProxy Logs (last 50 lines) ======="
    docker compose logs --tail=50 haproxy
    echo

    echo "======= Config Generator Logs (last 50 lines) ======="
    docker compose logs --tail=50 config_generator
    echo

    echo "======= Listening Ports ======="
    ss -tulpn
    echo

    echo "======= IPv6 Connectivity Test ======="
    if [ -n "$SUBNET" ]; then
        TEST_IP=$(grep -oE '\[[0-9a-fA-F:]+\]' "$HAPROXY_CFG" | head -n1 | tr -d '[]')
        if [ -n "$TEST_IP" ]; then
            ping6 -c 3 "$TEST_IP" || echo "ping6 to $TEST_IP failed"
            curl -g -6 -m 5 "http://[$TEST_IP]/" 2>&1 || echo "curl -6 to $TEST_IP failed"
        else
            echo "No IPv6 address found in HAProxy config"
        fi
    else
        echo "SUBNET not set in $CONFIG_ENV"
    fi
    echo

    echo "======= IPv4 Connectivity Test ======="
    if [ -n "$IPV4_ADDRESS" ]; then
        ping -c 3 "$IPV4_ADDRESS" || echo "ping to $IPV4_ADDRESS failed"
        curl -4 -m 5 "http://$IPV4_ADDRESS" 2>&1 || echo "curl -4 to $IPV4_ADDRESS failed"
    else
        echo "IPV4_ADDRESS not set in $CONFIG_ENV"
    fi
    echo

    echo "======= Firewall Rules ======="
    iptables -S
    ip6tables -S
    echo

} > "$REPORT" 2>&1

echo "Troubleshooting report saved to $REPORT"
