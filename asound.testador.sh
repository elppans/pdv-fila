#!/bin/bash

set -euo pipefail

LOG_FILE="/tmp/asound-teste.log"
touch "$LOG_FILE"

# Verifica se os utilitários necessários estão disponíveis
for cmd in dialog aplay speaker-test; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌ Requer o comando '$cmd'. Instale com: sudo apt install alsa-utils dialog"
        exit 1
    fi
done

# Função para obter lista de dispositivos com nomes amigáveis
listar_dispositivos() {
    local idx=0
    mapfile -t dispositivos < <(aplay -l | awk -F'[:,]' '/^card/ {
        gsub(/^[ \t]+|[ \t]+$/, "", $0)
        card_num=$2; name=$3; dev=$6; descr=$7  # Mudei 'card' para 'card_num' aqui
        gsub(/^[ \t]+|[ \t]+$/, "", name)
        gsub(/^[ \t]+|[ \t]+$/, "", descr)
        printf("card:%s hw:%s,%s - %s %s\n", idx++, card_num, dev, name, descr)  # Use card_num aqui
    }')
}

# Função para escrever .asoundrc
salvar_como_padrao() {
    local card="$1"
    local device="$2"
    # echo "DEBUG: card=$card, device=$device" >> "$LOG_FILE" # Linha de debug temporária
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
    dialog --msgbox "Dispositivo salvo como padrão em:\n$arquivo" 8 50
}

# Função de teste com som de 440Hz
teste_som_hw() {
    local metodo="$1"
    local dispositivo="$2"
    dialog --title "🔊 Testando áudio" --infobox \
    "Testando som com: ${metodo}:${dispositivo}\nVocê ouvirá um tom de 440Hz por 3 segundos..." 8 60
    speaker-test -t sine -f 440 -D "${metodo}:${dispositivo}" -c 2 -l 1 >/dev/null 2>&1 &
    pid=$!
    sleep 4
    kill $pid 2>/dev/null
}

# Função de teste com arquivo WAV
teste_som_wav() {
    local metodo="$1"
    local dispositivo="$2"
    if [ ! -f /usr/share/sounds/alsa/Front_Center.wav ]; then
        dialog --msgbox "Arquivo WAV não encontrado para teste." 6 40
        return
    fi
    aplay -D "${metodo}:${dispositivo}" /usr/share/sounds/alsa/Front_Center.wav
}

# Função principal de loop
loop_principal() {
    while true; do
        listar_dispositivos

        if [ ${#dispositivos[@]} -eq 0 ]; then
            dialog --msgbox "Nenhum dispositivo de saída encontrado com 'aplay -l'." 8 50
            exit 1
        fi

        # Cria lista de seleção
        menu_itens=()
        for linha in "${dispositivos[@]}"; do
            idx=$(echo "$linha" | awk '{print $1}')
            desc=$(echo "$linha" | cut -d' ' -f2-)
            menu_itens+=("$idx" "$desc")
        done

        # Seleção de dispositivo
        escolha=$(dialog --clear --title "Testador de Áudio ALSA" \
            --menu "Selecione um dispositivo para testar:" 20 72 10 \
            "${menu_itens[@]}" \
            3>&1 1>&2 2>&3) || break

        linha_escolhida="${dispositivos[$escolha]}"
        # Extrai card e device diretamente da string formatada
        card=$(echo "$linha_escolhida" | awk -F'[, ]+' '{print $2}' | tr -d ':')  # Pega o número após "card:"
        device=$(echo "$linha_escolhida" | awk -F'[, ]+' '{print $4}')  # Pega o número após "hw:"

        # Adicione também um debug temporário para verificar:
        echo "DEBUG: linha_escolhida=$linha_escolhida" >> "$LOG_FILE"
        echo "DEBUG: card=$card, device=$device" >> "$LOG_FILE"

        # Seleção do modo
        metodo=$(dialog --clear --title "Modo de Teste" \
            --menu "Escolha o modo de acesso ao dispositivo:" 12 72 2 \
            "hw" "Acesso direto (pode falhar se o formato não for aceito)" \
            "plughw" "Acesso com conversão automática (mais seguro)" \
            3>&1 1>&2 2>&3) || break

        echo "$(date +%F\ %T) Testando ${metodo}:${dispositivo}" >> "$LOG_FILE"

        # Escolha do tipo de teste
        tipo=$(dialog --title "Tipo de Teste" --menu "Escolha o tipo de teste:" 12 60 2 \
            "1" "Tom contínuo (440Hz por 3s)" \
            "2" "Áudio de teste Front_Center.wav" \
            3>&1 1>&2 2>&3) || break

        case "$tipo" in
            1) teste_som_hw "$metodo" "$dispositivo" ;;
            2) teste_som_wav "$metodo" "$dispositivo" ;;
        esac

        # Confirmação final
        dialog --yesno "Você ouviu som em ${metodo}:${dispositivo}?\n\nDeseja salvar como padrão?" 9 60
        resposta=$?
        if [ "$resposta" -eq 0 ]; then
            salvar_como_padrao "$card" "$device"
        fi

        # Deseja testar outro?
        dialog --yesno "Deseja testar outro dispositivo?" 7 50 || break
    done

    clear
    echo "✅ Log do teste salvo em: $LOG_FILE"
}

loop_principal
