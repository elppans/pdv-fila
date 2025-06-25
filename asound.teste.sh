#!/bin/bash

echo "🔎 Detectando saídas de áudio disponíveis..."

# Pega todos os pares card/device de saída listados pelo ALSA
mapfile -t dispositivos < <(aplay -l | grep "^card" | sed -E 's/^card ([0-9]+):.*device ([0-9]+):.*/\1,\2/')

if [ ${#dispositivos[@]} -eq 0 ]; then
    echo "❌ Nenhum dispositivo de saída encontrado com 'aplay -l'."
    exit 1
fi

echo "✅ Encontrados ${#dispositivos[@]} dispositivos:"
for entrada in "${dispositivos[@]}"; do
    IFS=',' read -r card device <<< "$entrada"
    echo "🔁 Testando hw:${card},${device} ..."
    speaker-test -t sine -f 440 -D hw:${card},${device} -c 2 -l 1 >/dev/null 2>&1 &
    pid=$!
    sleep 3
    kill $pid
done

echo
echo "✅ Teste finalizado. Se ouviu som em algum teste, anote o card/device correspondente!"
