#!/bin/bash

echo "🔎 Detectando saídas de áudio disponíveis..."

mapfile -t dispositivos < <(aplay -l | grep "^card" | sed -E 's/^card ([0-9]+):.*device ([0-9]+):.*/\1,\2/')

if [ ${#dispositivos[@]} -eq 0 ]; then
    echo "❌ Nenhum dispositivo de saída encontrado com 'aplay -l'."
    exit 1
fi

echo "✅ Encontrados ${#dispositivos[@]} dispositivos:"
for entrada in "${dispositivos[@]}"; do
    IFS=',' read -r card device <<< "$entrada"
    echo "🔁 Testando hw:${card},${device} ..."

    # Rodar o speaker-test por 3 segundos
    speaker-test -t wav -f 440 -D plughw:${card},${device} -c 2 -l 1 &
    pid=$!
    
    # Esperar um pouco mais para garantir que o som saia
    sleep 4

    # Verifica se o processo ainda está rodando antes de matar
    if ps -p $pid > /dev/null; then
        kill $pid
    fi

    sleep 1
done

echo
echo "✅ Teste finalizado. Se ouviu som em algum teste, anote o card/device correspondente!"
