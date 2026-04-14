# Dual WAN — split routing para download e upload em interfaces separadas

# Configura e ativa o split routing dual-WAN
[group('Network')]
setup-dual-wan:
    #!/usr/bin/bash
    set -euo pipefail

    echo "=== Configuração Dual WAN ==="
    echo ""

    # Lista interfaces disponíveis (excluindo lo e virtuais)
    mapfile -t IFACES < <(ip -br link show | awk '$2 == "UP" {print $1}' | grep -v '^lo$')

    if [[ ${#IFACES[@]} -lt 2 ]]; then
        echo "Erro: são necessárias ao menos 2 interfaces UP."
        echo "Interfaces UP encontradas: ${IFACES[*]:-nenhuma}"
        exit 1
    fi

    echo "Interfaces de rede disponíveis (UP):"
    for i in "${!IFACES[@]}"; do
        IFACE="${IFACES[$i]}"
        IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "sem IP")
        echo "  [$i] $IFACE  ($IP)"
    done
    echo ""

    # Interface de download
    while true; do
        read -rp "Qual interface tem melhor DOWNLOAD? (número ou nome): " DL_INPUT
        if [[ "$DL_INPUT" =~ ^[0-9]+$ ]] && [[ -n "${IFACES[$DL_INPUT]:-}" ]]; then
            DL_IFACE="${IFACES[$DL_INPUT]}"
            break
        elif ip link show "$DL_INPUT" &>/dev/null; then
            DL_IFACE="$DL_INPUT"
            break
        else
            echo "Interface inválida, tente novamente."
        fi
    done

    # Interface de upload
    while true; do
        read -rp "Qual interface tem melhor UPLOAD? (SSH/rsync/git passam por ela) (número ou nome): " UL_INPUT
        if [[ "$UL_INPUT" =~ ^[0-9]+$ ]] && [[ -n "${IFACES[$UL_INPUT]:-}" ]]; then
            UL_IFACE="${IFACES[$UL_INPUT]}"
            break
        elif ip link show "$UL_INPUT" &>/dev/null; then
            UL_IFACE="$UL_INPUT"
            break
        else
            echo "Interface inválida, tente novamente."
        fi
    done

    if [[ "$DL_IFACE" == "$UL_IFACE" ]]; then
        echo "Erro: as interfaces precisam ser diferentes."
        exit 1
    fi

    # Detectar gateways automaticamente
    DL_GW_AUTO=$(ip route show dev "$DL_IFACE" | awk '/default/ {print $3}' | head -1 || true)
    UL_GW_AUTO=$(ip route show dev "$UL_IFACE" | awk '/default/ {print $3}' | head -1 || true)

    # Gateway download
    read -rp "Gateway para $DL_IFACE (download) [${DL_GW_AUTO:-?}]: " DL_GW_INPUT
    DL_GW="${DL_GW_INPUT:-$DL_GW_AUTO}"
    if [[ -z "$DL_GW" ]]; then
        echo "Erro: gateway de download não pode ser vazio."
        exit 1
    fi

    # Gateway upload
    read -rp "Gateway para $UL_IFACE (upload) [${UL_GW_AUTO:-?}]: " UL_GW_INPUT
    UL_GW="${UL_GW_INPUT:-$UL_GW_AUTO}"
    if [[ -z "$UL_GW" ]]; then
        echo "Erro: gateway de upload não pode ser vazio."
        exit 1
    fi

    echo ""
    echo "Resumo:"
    echo "  Download : $DL_IFACE → gateway $DL_GW"
    echo "  Upload   : $UL_IFACE → gateway $UL_GW  (SSH, rsync, git, HTTPS >5MB)"
    echo ""
    read -rp "Confirmar? [S/n]: " CONFIRM
    [[ "${CONFIRM,,}" == "n" ]] && echo "Cancelado." && exit 0

    # Gravar config
    printf '# Gerado por ujust setup-dual-wan\nDL_IFACE="%s"\nDL_GW="%s"\nUL_IFACE="%s"\nUL_GW="%s"\n' \
        "$DL_IFACE" "$DL_GW" "$UL_IFACE" "$UL_GW" | sudo tee /etc/dual-wan.conf > /dev/null

    sudo systemctl enable dual-wan.service
    sudo systemctl start dual-wan.service
    sudo systemctl enable dual-wan.timer
    sudo systemctl start dual-wan.timer

    echo ""
    echo "Dual WAN ativo!"
    echo ""
    ip rule show
    ip route get 8.8.8.8

# Desativa split routing dual-WAN
[group('Network')]
disable-dual-wan:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Desativando dual-WAN..."
    sudo systemctl stop dual-wan.timer dual-wan.service || true
    sudo systemctl disable dual-wan.timer dual-wan.service || true
    sudo rm -f /etc/dual-wan.conf
    echo "Desativado. Reinicie para restaurar rotas padrão."

# Força reaplicação das regras dual-WAN agora
[group('Network')]
apply-dual-wan:
    #!/usr/bin/bash
    set -euo pipefail
    sudo /usr/local/bin/dual-wan.sh
    echo ""
    ip rule show
    ip route get 8.8.8.8

# Status do dual-WAN
[group('Network')]
dual-wan-status:
    #!/usr/bin/bash
    echo "=== Config ==="
    cat /etc/dual-wan.conf 2>/dev/null || echo "(não configurado — execute: ujust setup-dual-wan)"
    echo ""
    echo "=== Serviços ==="
    SYSTEMD_PAGER="" systemctl status dual-wan.service dual-wan.timer || true
    echo ""
    echo "=== Regras de rota ==="
    ip rule show
    echo ""
    echo "=== Rota para internet ==="
    ip route get 8.8.8.8
    echo ""
    echo "=== Marcação iptables ==="
    sudo iptables -t mangle -L DUAL_WAN -v 2>/dev/null || echo "(sem regras ativas)"
