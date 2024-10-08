#!/bin/bash

# Variáveis para configuração de monitores
monitor1='eDP-1'
monitor2='VGA-1'
resolucao1='800x600'
resolucao2='1360x768'
posicao1='0x0' # Posicao Horizontal x Vertical, 1º monitor
posicao2='800x0' # Posição após o valor "Horizontal" do 1º monitor. 2º monitor

# Substitui 'x' por ','
posicaox1="$(echo $posicao1 | sed 's/x/,/')"
posicaox2="$(echo $posicao2 | sed 's/x/,/')"

# Exportando todas as variáveis
export monitor1
export monitor2
export resolucao1
export resolucao2
export posicao1
export posicao2
export posicaox1
export posicaox2

# Configura a resolução e posição dos monitores
xrandr --output "$monitor1" --mode "$resolucao1" --pos "$posicao1" --output "$monitor2" --mode "$resolucao2"  --pos "$posicao2"

# Função para definir um Loop/Tempo
sleeping() {
    local time
    time="$1"
for i in $(seq "$time" -1 1); do
    echo -ne "$i Seg.\r"
    sleep 1
done
}

# Função para verificar e posicionar a janela Java
pdvjava_param() {
  while true; do
    WMID=$(wmctrl -l | grep "Zanthus Retail" | cut -d " " -f1)
    if [ -z "$WMID" ]; then
      echo "Aguardando 'Zanthus Retail' iniciar..."
      sleeping 5
      clear
    else
      # Garantir que o Java seja configurado na posição parametrizada.
      wmctrl -i -r $WMID -e "0,$posicaox1,-1,-1"
      echo "Janela 'Zanthus Retail' encontrada e configurada."
      break
    fi
  done
}

# Função para executar o Java (base PDVJava)
pdvjava_exec() {
/usr/bin/unclutter 1> /dev/null &
chmod +x /usr/local/bin/igraficaJava
chmod -x /usr/local/bin/dualmonitor_control-PDVJava
nohup dualmonitor_control-PDVJava &>>/dev/null &
nohup igraficaJava &>>/dev/null &
nohup recreate-user-rabbitmq.sh &>>/dev/null &
echo "Iniciando pdvJava2..."
nohup xterm -e "/Zanthus/Zeus/pdvJava/pdvJava2" &>>/dev/null &
pdvjava_param
}

# Função para executar o Painel Chama Fila
painel_exec() {
# Configuração de Profile e Storage
local temp_profile
local local_storage

temp_profile="$HOME/.painel/chromium"
local_storage="$temp_profile/Default/Local Storage"

mkdir -p "$local_storage"

echo "Iniciando Painel..."
sleeping 10

# Limpar informações de profile, mas manter configuração do Painel
find "$temp_profile" -mindepth 1 -not -path "$local_storage/*" -delete &>>/dev/null

# Executar Chromium com uma nova instância
setsid nohup chromium-browser --no-sandbox \
--test-type \
--no-default-browser-check \
--disable-session-crashed-bubble \
--restore-last-session=false \
--disable-infobars \
--disable-background-networking \
--disable-component-extensions-with-background-pages \
--disable-features=SessionRestore \
--disable-restore-session-state \
--disable-features=DesktopPWAsAdditionalWindowingControls \
--disable-features=TabRestore \
--user-data-dir="$temp_profile" \
--autoplay-policy=no-user-gesture-required \
--enable-speech-synthesis \
--kiosk \
http://127.0.0.1:9090/moduloPHPPDV/painel.php --window-position="$posicaox2" &>>/dev/null &
}

# Execução das funções
pdvjava_exec
painel_exec

# Finalização
echo "Esta janela será fechada após..."
sleeping 55
