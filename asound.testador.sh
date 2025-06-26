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
        card=$2; name=$3; dev=$6; descr=$7
        gsub(/^[ \t]+|[ \t]+$/, "", name)
        gsub(/^[ \t]+|[ \t]+$/, "", descr)
        printf("%s hw:%s,%s - %s: %s\n", idx++, card, dev, name, descr)
    }')
}

# Função para escrever .asoundrc
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
        echo "DEBUG: metodo=$metodo" >> "$LOG_FILE"
        echo "DEBUG: dispositivo=$dispositivo" >> "$LOG_FILE"

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
        echo "DEBUG: metodo=$metodo" >> "$LOG_FILE"
        echo "DEBUG: dispositivo=$dispositivo" >> "$LOG_FILE"
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
	    echo "DEBUG: linha=$linha" >> "$LOG_FILE"
	    echo "DEBUG: idx=$idx" >> "$LOG_FILE"
	    echo "DEBUG: desc=$desc" >> "$LOG_FILE"
	    echo "DEBUG: menu_itens=$menu_itens" >> "$LOG_FILE"
        done

        # Seleção de dispositivo
        escolha=$(dialog --clear --title "Testador de Áudio ALSA" \
            --menu "Selecione um dispositivo para testar:" 20 72 10 \
            "${menu_itens[@]}" \
            3>&1 1>&2 2>&3)

     # Se o usuário cancelou, volta pro início ao invés de quebrar
if [ $? -ne 0 ]; then
    dialog --msgbox "Cancelado pelo usuário. Retornando ao menu principal." 6 50
    continue
fi

        linha_escolhida="${dispositivos[$escolha]}"
        dispositivo="$(echo "$linha_escolhida" | awk '/hw:/ {
    gsub(/[^0-9]/, "", $1)
    gsub(/[^0-9]/, "", $NF)
    print $1","$NF
}')"
        card=$(echo "$dispositivo" | cut -d',' -f1 | awk -F'[:, ]+' '{print $1}')
        device=$(echo "$linha_escolhida" | cut -d',' -f2 | awk -F'[:, ]+' '{print $4}')

        echo "DEBUG: dispositivos=$dispositivos" >> "$LOG_FILE"
        echo "DEBUG: dispositivo=$dispositivo" >> "$LOG_FILE"
        echo "DEBUG: escolha=$escolha" >> "$LOG_FILE"
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
while true; do
    tipo=$(dialog --title "Tipo de Teste" --menu "Escolha o tipo de teste:" 12 60 2 \
        "1" "Tom contínuo (440Hz por 3s)" \
        "2" "Áudio de teste Front_Center.wav" \
        3>&1 1>&2 2>&3) || break

    if [ "$tipo" = "2" ] && [ "$metodo" = "hw" ]; then
        dialog --msgbox "❌ O modo 'hw' não suporta reprodução de arquivos WAV com conversão automática.\n\nPor favor, use o modo 'plughw' para esse tipo de teste." 10 60
        continue  # Volta para escolher o tipo de teste
    else
        break  # Tipo de teste válido, segue o fluxo
    fi
done


        case "$tipo" in
            1) teste_som_hw "$metodo" "$dispositivo" ;;
            2) teste_som_wav "$metodo" "$dispositivo" ;;
        esac

        # Confirmação final
dialog --yesno "Você ouviu som em ${metodo}:${dispositivo}?\n\nDeseja salvar como padrão?" 9 60
resposta=$?
if [ "$resposta" -eq 0 ]; then
    salvar_como_padrao "$card" "$device"
else
    dialog --msgbox "Dispositivo **não** foi salvo como padrão. Voltando ao menu..." 7 50 || continue
fi


        # Deseja testar outro?
        dialog --yesno "Deseja testar outro dispositivo?" 7 50 || break
    done

    clear
    echo "✅ Log do teste salvo em: $LOG_FILE"
}

loop_principal
