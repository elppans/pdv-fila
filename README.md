# pdv-fila
___
- **Script para execução do PDV com `Painel Chama Fila`.**

1) Faça Download do arquivo `chama_fila.zip` do **FTP Z...**, extraia e configure conforme manual `GCCF0106`;  
2) Substitua o Script principal do pacote zip por este, no diretório `pdvJava`;  
3) Deve editar o arquivo `/usr/local/bin/mainapp` e trocar a execução em xterm configurado pelo comando a seguir:  

```bash
xterm -e /Zanthus/Zeus/pdvJava/PDVPainel.sh
```
___
# Script `PDVFunctions.sh`: Configuração e Utilização

**Descrição:**

Este script automatiza o processo de chamada de fila, integrando-se com sistemas PDV Java e Interfaces. Ele oferece flexibilidade para configurar e executar diferentes componentes de acordo com a necessidade.
>Configure `PDVFunctions.sh` no lugar de `PDVPainel.sh`

**Funcionamento:**

* **Funções:** O script é organizado em funções, facilitando a manutenção e reutilização de código.
* **Componentes:**
    * **PDV Java:** Base do sistema de ponto de venda.
    * **Interface:** Interface gráfica (PDVToutch) para interação com o usuário.
    * **Painel Chama Fila:** Exibe as informações da fila para os clientes.
* **Configuração:**
    * **Componentes Ativos:** No final do arquivo, comente ou descomente as linhas das funções que deseja executar:
        * `pdvjava_exec`: Executa o PDV Java.
        * `interface_exec`: Executa a interface.
        * `painel_exec`: Executa o painel de chama fila.
    * **Monitores:** A configuração dos monitores é manual para maior flexibilidade.
        * **Identificação:** Utilize o comando `xrandr` no PDV para identificar os monitores (ex: `DP-3`, `HDMI-2`).
        * **Resolução:** Defina a resolução de cada monitor (ex: `1024x768`, `1920x1080`).
        * **Variáveis:** No início do script, atribua os valores identificados às variáveis `monitor1`, `monitor2`, `resolucao1` e `resolucao2`.
        * **Posição:** A posição dos monitores é configurada automaticamente após definir o monitor e a resolução.

**Exemplo de Configuração:**

```
monitor1='DP-3'
monitor2='HDMI-2'
resolucao1='1024x768'
resolucao2='1920x1080'
```

**Para utilizar apenas o PDV Java:**

1. Comente a linha `interface_exec`.
2. Descomente a linha `pdvjava_exec`.


