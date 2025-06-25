#!/bin/bash

# Verifica se o utilitário "dialog" está disponível
if ! command -v dialog &>/dev/null; then
    echo "❌ O utilitário 'dialog' não está instalado. Instale com: sudo apt install dialog"
    exit 1
fi

# Detecta os dispositivos de saída
mapfile -t dispositivos < <(aplay -l | grep "^card" | sed -E 's/^card ([0-9]+):.*device ([0-9]+):.*/\1,\2/')

if [ ${#dispositivos[@]} -eq 0 ]; then
    dialog --msgbox "Nenhum dispositivo de saída encontrado com 'aplay -l'." 8 40
    exit 1
fi

# Prepara lista para o menu do dialog
menu_items=()
for i in "${!dispositivos[@]}"; do
    menu_items+=("$i" "Dispositivo hw:${dispositivos[$i]}")
done

# Exibe menu para escolher o dispositivo
escolha=$(dialog --clear --title "Testador de Áudio ALSA" \
    --menu "Selecione um dispositivo para testar:" 15 60 6 \
    "${menu_items[@]}" \
    3>&1 1>&2 2>&3)

# Se o usuário cancelou
if [ -z "$escolha" ]; then
    clear
    echo "❌ Cancelado pelo usuário."
    exit 1
fi

selecionado="${dispositivos[$escolha]}"

# Pergunta se quer testar com hw ou plughw
metodo=$(dialog --clear --title "Modo de Teste" \
    --menu "Escolha o modo de acesso ao dispositivo:" 12 72 2 \
    "hw" "Acesso direto (pode falhar se o formato não for aceito)" \
    "plughw" "Acesso com conversão automática (mais seguro)" \
    3>&1 1>&2 2>&3)

if [ -z "$metodo" ]; then
    clear
    echo "❌ Cancelado pelo usuário."
    exit 1
fi

# Mostra caixa de informação enquanto toca o som
dialog --title "🔊 Testando áudio" --infobox \
"Testando som com: ${metodo}:${selecionado}\n\nVocê ouvirá um tom de 440Hz por 3 segundos..." 8 60

# Executa o teste em background
speaker-test -t sine -f 440 -D ${metodo}:${selecionado} -c 2 -l 1 >/dev/null 2>&1 &
pid=$!
sleep 4
kill $pid 2>/dev/null

# Mostra resultado
dialog --title "✅ Teste finalizado" --msgbox \
"O teste foi concluído.\n\nSe você ouviu som, o dispositivo ${metodo}:${selecionado} está funcionando corretamente!" 8 60

clear
