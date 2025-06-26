#!/bin/bash

set -euo pipefail

LOG_FILE="/tmp/asound-teste.log"
touch "$LOG_FILE"

# Verifica dependências
for cmd in dialog aplay speaker-test; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌ Requer o comando '$cmd'. Instale com: sudo apt install alsa-utils dialog"
        exit 1
    fi
done

# Lista dispositivos no formato limpo do aplay -l
listar_dispositivos() {
    mapfile -t dispositivos < <(aplay -l | awk '/^card/ {print $0}')
}

# Salva configuração no .asoundrc
salvar_como_padrao() {
    local card="$1"
    local device="$2"
    local arquivo="$HOME/.asoundrc"
    cat > "$arquivo" <<EOF
pcm.!default {
    type plug
    slave.pcm "hw:${card},${device}"
}

ctl.!default {
    type hw
    card ${card}
}
EOF
    dialog --msgbox "Configuração salva em:\n$arquivo\n\nCard: ${card}\nDevice: ${device}" 10 50
}

# Teste com tom de 440Hz
teste_som_hw() {
    local metodo="$1"
    local dispositivo="$2"
    dialog --title "🔊 Testando áudio" --infobox \
    "Testando som com: ${metodo}:${dispositivo}\nTom de 440Hz por 3 segundos..." 8 60
    speaker-test -t sine -f 440 -D "${metodo}:${dispositivo}" -c 2 -l 1 >/dev/null 2>&1 &
    pid=$!
    sleep 4
    kill $pid 2>/dev/null
}

# Teste com arquivo WAV
teste_som_wav() {
    local metodo="$1"
    local dispositivo="$2"
    if [ ! -f /usr/share/sounds/alsa/Front_Center.wav ]; then
        dialog --msgbox "Arquivo WAV não encontrado para teste." 6 40
        return
    fi
    aplay -D "${metodo}:${dispositivo}" /usr/share/sounds/alsa/Front_Center.wav
}

# Loop principal
loop_principal() {
    while true; do
        listar_dispositivos

        if [ ${#dispositivos[@]} -eq 0 ]; then
            dialog --msgbox "Nenhum dispositivo de áudio encontrado!" 8 50
            exit 1
        fi

        # Cria menu (índices invisíveis)
        menu_itens=()
        local idx=0
        for linha in "${dispositivos[@]}"; do
            menu_itens+=("$idx" "$linha")
            ((idx++))
        done

        # Seleção do dispositivo
        escolha=$(dialog --menu "Selecione o dispositivo:" 20 80 10 \
            "${menu_itens[@]}" 3>&1 1>&2 2>&3) || break

        linha_escolhida="${dispositivos[$escolha]}"
        
        # Extrai card e device
        card=$(echo "$linha_escolhida" | awk '{print $2}' | tr -d ':')
        device=$(echo "$linha_escolhida" | awk -F'device |:' '{print $2}' | tr -d ' ')

        if ! [[ "$card" =~ ^[0-9]+$ ]] || ! [[ "$device" =~ ^[0-9]+$ ]]; then
            dialog --msgbox "Erro: Não foi possível extrair card/device" 8 50
            continue
        fi

        # Seleção do método
        metodo=$(dialog --menu "Modo de acesso:" 12 60 2 \
            "hw" "Acesso direto" \
            "plughw" "Acesso com conversão" \
            3>&1 1>&2 2>&3) || continue

        echo "$(date +%F\ %T) Testando ${metodo}:${card},${device}" >> "$LOG_FILE"

        # Tipo de teste
        tipo=$(dialog --menu "Tipo de teste:" 12 60 2 \
            "1" "Tom contínuo (440Hz)" \
            "2" "Áudio de teste (WAV)" \
            3>&1 1>&2 2>&3) || continue

        case "$tipo" in
            1) teste_som_hw "$metodo" "${card},${device}" ;;
            2) teste_som_wav "$metodo" "${card},${device}" ;;
        esac

        # Confirmação
        dialog --yesno "Você ouviu som em ${metodo}:${card},${device}?\n\nDeseja salvar como padrão?" 9 60 && {
            salvar_como_padrao "$card" "$device"
        }

        # Testar outro?
        dialog --yesno "Deseja testar outro dispositivo?" 7 50 || break
    done

    clear
    echo "✅ Log do teste salvo em: $LOG_FILE"
}

# Inicia o script
loop_principal
