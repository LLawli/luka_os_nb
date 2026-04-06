# vim: set ft=make :
alias configure-waydroid := setup-waydroid

# Configura e gerencia o Waydroid (Android no Linux)
[group('Apps')]
setup-waydroid ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
        echo "Uso: ujust configure-waydroid <opção>"
        echo " <opção>: Especifique a opção para pular o menu interativo"
        echo " Use 'init'        para Inicializar o Waydroid"
        echo " Use 'configure'   para Configurar o Waydroid (Google Play, ARM, etc)"
        echo " Use 'integration' para ativar integração de janelas no desktop"
        echo " Use 'reset'       para Resetar o Waydroid (remove todos os dados)"
        echo " Use 'helper'      para instalar o waydroid-helper"
        exit 0
    elif [ "$OPTION" == "" ]; then
        echo "${bold}Configuração do Waydroid${normal}"
        OPTION=$(Choose \
            "Inicializar Waydroid" \
            "Configurar Waydroid (Google Play, ARM, etc)" \
            "Ativar integração de janelas no desktop" \
            "Resetar Waydroid (remove todos os dados)" \
            "Instalar waydroid-helper")
    fi

    if [[ "${OPTION,,}" =~ ^init ]]; then
        sudo systemctl enable --now waydroid-container
        echo "Inicializando o Waydroid, aguarde..."
        sudo waydroid init -c 'https://ota.waydro.id/system' -v 'https://ota.waydro.id/vendor'
        sudo restorecon -R /var/lib/waydroid
        mkdir -p ~/.local/share/applications
        cp /usr/share/applications/waydroid-container-restart.desktop ~/.local/share/applications/
        echo "Waydroid inicializado! Execute-o uma vez antes de usar 'Configurar'."

    elif [[ "${OPTION,,}" =~ ^configure ]]; then
        git clone https://github.com/ublue-os/waydroid_script.git --depth 1 /tmp/waydroid_script
        python -m venv /tmp/waydroid_script/venv
        source /tmp/waydroid_script/venv/bin/activate
        sudo pip install -r /tmp/waydroid_script/requirements.txt
        sudo /tmp/waydroid_script/main.py
        deactivate
        sudo rm -rf /tmp/waydroid_script

    elif [[ "${OPTION,,}" =~ integration ]]; then
        waydroid prop set persist.waydroid.multi_windows true
        echo "Integração de janelas ativada. Reinicie o Waydroid para aplicar."

    elif [[ "${OPTION,,}" =~ ^reset ]]; then
        echo "Resetando o Waydroid..."
        sudo systemctl stop waydroid-container || true
        sudo rm -rf /var/lib/waydroid /home/.waydroid ~/waydroid
        rm -rf ~/.share/waydroid ~/.local/share/waydroid
        rm -f ~/.local/share/applications/*aydroid* ~/.local/share/applications/*aydroid*
        echo "Waydroid resetado com sucesso."

    elif [[ "${OPTION,,}" =~ helper ]]; then
        echo "Instalando waydroid-helper..."
        if grep -q 'it.mijorus.gearlever' <<< $(flatpak list); then
            wget \
                $(curl -s https://api.github.com/repos/waydroid-helper/waydroid-helper/releases/latest | \
                jq -r ".assets[] | select(.name | test(\".*x86_64.AppImage\")) | .browser_download_url") \
                -O "$HOME/Downloads/waydroid-helper.AppImage"
            chmod +x "$HOME/Downloads/waydroid-helper.AppImage"
            echo "Download concluído. Adicionando ao menu via Gear Lever..."
            flatpak run it.mijorus.gearlever "$HOME/Downloads/waydroid-helper.AppImage"
        else
            wget \
                $(curl -s https://api.github.com/repos/waydroid-helper/waydroid-helper/releases/latest | \
                jq -r ".assets[] | select(.name | test(\".*AppImage\")) | .browser_download_url") \
                -O "$HOME/Desktop/waydroid-helper.AppImage"
            chmod +x "$HOME/Desktop/waydroid-helper.AppImage"
            echo "Instalado no Desktop."
        fi
    fi
