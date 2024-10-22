#!/bin/bash

# Variáveis para configuração de monitores
monitor1='VGA-1'
monitor2='HDMI-1'
resolucao1='1024x768'
resolucao2='1440x900'
posicao1='0x0'   # Posicao Horizontal x Vertical, 1º monitor
# posicao2='1024x0' # Posição após o valor "Horizontal" do 1º monitor. 2º monitor

# Extrair a largura do primeiro monitor
largura_monitor1=$(echo "$resolucao1" | cut -dx -f1)

# Construir a nova posição para o segundo monitor
nova_posicao2="$largura_monitor1x0"

# Substituir a variável posicao2
posicao2="$nova_posicao2" # Posição do 2º monitor, automatico

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
xrandr --output "$monitor1" --mode "$resolucao1" --pos "$posicao1" --output "$monitor2" --mode "$resolucao2" --pos "$posicao2"

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

# Função para verificar e posicionar a janela Interface PDV
interface_param() {
  while true; do
    WMID=$(wmctrl -l | grep "Interface PDV" | cut -d " " -f1)
    if [ -z "$WMID" ]; then
      echo "Aguardando 'Interface PDV' iniciar..."
      sleeping 5
      clear
    else
      # Garantir que o Java seja configurado na posição parametrizada.
      wmctrl -i -r $WMID -e "0,$posicaox1,-1,-1"
      echo "Janela 'Interface PDV' encontrada e configurada."
      break
    fi
  done
}

# Função para executar ctsat
# Não é necessário para pdvjava_exec
# Usar com "interface_exec"
ctsat_exec() {
  pkill -9 lnx_ctsat
  echo -e "[INICIANDO SERVICO CTSAT]\n"
  cd /Zanthus/Zeus/ctsat
  xterm -T "Servico CTSAT" -geometry 60x24+360+0 -e "$(pwd)/lnx_ctsat.xz64" &
}

# Função para executar o paf/receb
# Não é necessário para pdvjava_exec
# Usar com "interface_exec"
paf_exec() {
  pkill -9 lnx_paf
  pkill -9 lnx_receb
  cd /Zanthus/Zeus/pdvJava
  export LANG=pt_BR.ISO8859-1
  xterm -T "Zeus Frente de Loja" -geometry 60x24+360+0 -e "$(pwd)/lnx_paf.xz64" &
}

# Função para executar o Java (base PDVJava)
pdvjava_exec() {
  /usr/bin/unclutter 1>/dev/null &
  chmod +x /usr/local/bin/igraficaJava
  chmod -x /usr/local/bin/dualmonitor_control-PDVJava
  nohup dualmonitor_control-PDVJava &>>/dev/null &
  nohup igraficaJava &>>/dev/null &
  nohup recreate-user-rabbitmq.sh &>>/dev/null &
  echo "Iniciando pdvJava2..."
  nohup xterm -e "/Zanthus/Zeus/pdvJava/pdvJava2" &>>/dev/null &
  pdvjava_param
}

# Função para executar o Interface
interface_exec() {
  paf_exec   # Executar o CODFON
  ctsat_exec # Executar o ctsat

  # Configuração de Profile e Storage
  local temp_profile
  local local_storage
  local interface

  temp_profile="$HOME/.interface/chromium"
  local_storage="$temp_profile/Default/Local Storage"
  interface="/Zanthus/Zeus/Interface"

  mkdir -p "$local_storage"
  chown -R zanthus:zanthus "$interface"
  echo "Iniciando interface..."
  sleeping 10

  # Limpar informações de profile, mas manter configuração do interface
  find "$temp_profile" -mindepth 1 -not -path "$local_storage/*" -delete &>>/dev/null

  # Executar Chromium com uma nova instância
  setsid nohup chromium-browser --no-sandbox \
    --test-type \
    --no-default-browser-check \
    --no-context-menu \
    --disable-gpu \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --disable-background-networking \
    --disable-component-extensions-with-background-pages \
    --disable-features=SessionRestore \
    --disable-restore-session-state \
    --disable-features=DesktopPWAsAdditionalWindowingControls \
    --disable-features=TabRestore \
    --disable-translate \
    --disk-cache-dir=/tmp/chromium-cache \
    --user-data-dir="$temp_profile" \
    --restore-last-session=false \
    --autoplay-policy=no-user-gesture-required \
    --enable-speech-synthesis \
    --kiosk \
    file:///"$interface"/index.html &>>/dev/null &
  interface_param
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
# pdvjava_exec    # Executar o Java (base PDVJava)
interface_exec # Executar o Interface (PDVToutch)
painel_exec    # Executar o Painel Chama Fila

# Finalização
echo "Esta janela será fechada após..."
sleeping 55
