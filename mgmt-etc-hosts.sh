#!/bin/bash
##Author: Syncophat, Ricardo Peña
##  +-----------------------------------------------------------------------+
##  |                                                                       |
##  | Copyright (c) 2019-2024, Ricardo Peña <syncophat.drums@gmail.com>.    |
##  |                                                                       |
##  | This program is free software: you can redistribute it and/or modify  |
##  | it under the terms of the GNU General Public License as published by  |
##  | the Free Software Foundation, either version 3 of the License, or     |
##  | (at your option) any later version.                                   |
##  |                                                                       |
##  | This program is distributed in the hope that it will be useful,       |
##  | but WITHOUT ANY WARRANTY; without even the implied warranty of        |
##  | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         |
##  | GNU General Public License for more details.                          |
##  |                                                                       |
##  | You should have received a copy of the GNU General Public License     |
##  | along with this program. If not, see <http://www.gnu.org/licenses/>.  |
##  |                                                                       |
##  +-----------------------------------------------------------------------+
#
#     Descripción
#
#     Este script esta pensado para administrar el achivo /etc/hosts, 
#     y enfocado para los administradores de redes, utilizando el consepto 
#     de que se hace una relación de dominios a una IP de forma local.
#     El ejemplo para lo que fue diseñado, es almacenar la IP y el hostname
#     del dispositivo, al usar las funciones de telnet o ssh, sean dirijidas
#     al nombre del dispositio.
#     "telnet SW_1 o ssh SW_1"
#
#     Este script tiene dos modos de utilización.
#     1. Modo exploración, nos permite buscar IP o Hostname 
#     2. Modo Cambios, nos permite hacer alta, baja o cambios
#
#Definiciñon de colores de la terminal.
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"
#Path hosts
ETC_HOSTS=/etc/hosts
#
#Función para habilitar el uso de ctrl_c para interrumpir y el envio del cursor nuevamente
#
trap ctrl_c INT
function ctrl_c (){
  echo -e "\n${redColour}[!] Saliendo...\n${endColour}"
  tput cnorm; exit 1 
}
#
#Funciones para crear tablas
#
function printTable(){

    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]];
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

function removeEmptyLines(){

    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString(){

    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString(){

    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){

    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}
#
#
#===================================================================
# Panel de ayuda 
#===================================================================
#
function helpPanel(){
  echo -e "\n${redColour}[!] Uso: mgmt-etc-hosts.sh ${endColour}"
  for i in $(seq 1 80); do echo -ne "${redColour}-"; done; echo -ne "${endColour}"
  echo -e "\n\n\t${grayColour}[-e]${endColour}${yellowColour} Modo Exploración${endColour}"
  echo -e "\t\t${purpleColour}busqueda_IP${endColour}${grayColour}[-e][-i]${endColour}${yellowColour}: Busca un Dev por IP${endColour}${blueColour}(ejemplo ./mgmt-etc-hosts.sh -e busqueda_IP -i 192.168.0.0 )"
  echo -e "\t\t${purpleColour}busqueda_HOST${endColour}${grayColour}[-e][-j]${endColour}${yellowColour}: Busca un Dev por hostname${endColour}${blueColour}(ejemplo ./mgmt-etc-hosts.sh -e busqueda_HOST -j hostname )"
  echo -e "\n\n\t${grayColour}[-a]${endColour}${yellowColour}Modo alta y cambios${endColour}"
  echo -e "\t\t${purpleColour}cambios${endColour}${yellowColour}:\t\t\t Cambio de Host o IP${endColour}"
  echo -e "\t\t${purpleColour}alta${endColour}${yellowColour}:\t\t\t Agrega un Dev en la lista${blueColour}(ejemplo ./mgmt-etc-hosts.sh -a alta -b 192.168.0.0 -c dev.com)${endColour}"
  echo -e "\t\t${purpleColour}baja${endColour}${yellowColour}:\t\t\t Elimina un Dev en la lista${endColour}${blueColour}(ejemplo ./mgmt-etc-hosts.sh -a baja -d 192.168.0.0 -f dev.com)${endColour}"
  echo -e "\n\t${grayColour}remplazo${endColour}${yellowColour} Cambiar IP o HOST del archivo hosts${endColour}"
  echo -e "\t\t${purpleColour}[-b -c -d -f]${endColour}${yellowColour}:\t\t\t IP y host en $ETC_HOSTS y IP y host a remplazar${endColour}${blueColour} ejemplo: .\mgmt-etc-hosts -a cambio -b 192.168.0.0 -c dev.com -d 192.168.1.0 -f dev.net${endColour}"
  echo -e "\n\t${grayColour}[-h]${endColour}${yellowColour} Mostrar este panel de ayuda${endColour}"
  tput cnorm; exit 1
}
#
#===================================================================
# Función para Buscar IP's
#===================================================================
#
function search_IP(){
  #IP a consultar
  ip=$1
  cont=0
  echo '' > ips.tmp
  while [ "$(cat ips.tmp | wc -l)" == "1" ] && [ "$cont" == "0" ]; do 
    $(cat $ETC_HOSTS | grep $ip  >> ips.tmp) 
    cont+=1;
  done
  Hostname=$(cat ips.tmp | grep $ip | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
  echo "IP~Host" > ips2.table
  echo '' > ips.table
  for ips in $Hostname; do
     echo "${ips}~$(cat ips.tmp | grep "^$ips" | awk '{print $2}')" >> ips.table
  done
    echo "$(cat ips.table | grep -E $ip | sort -n  | uniq )">> ips2.table
    printTable '~' "$(cat ips2.table)"
    rm ips*
    tput cnorm;
   }
#
#===================================================================
# Función para Buscar Hosts's
#===================================================================
#
function search_HOST(){
  #HOSTNAME a consultar
  hosts=$1
  cont=0
  echo '' > ips.tmp
  while [ "$(cat ips.tmp | wc -l)" == "1" ] && [ "$cont" == "0" ]; do 
    $(cat $ETC_HOSTS | grep $hosts >> ips.tmp)
    cont+=1
  done
  echo "Host~IP" > ips2.table
  Hostname=$(cat ips.tmp | grep $hosts | awk '{print $2}')
  echo '' > ips.table 
  for hostname in $Hostname; do 
    echo "${hostname}~$(cat ips.tmp | grep $hostname | awk '{print $1}' )" >> ips.table
  done
  echo "$(cat ips.table | grep -E $hosts | sort -h | uniq )">>ips2.table
  printTable '~' "$(cat ips2.table)"
  rm ips*
  tput cnorm;
}
#
#===================================================================
# Función para dar de alta nuevos dispositivos en el /etc/hosts 
#===================================================================
#
function alta(){
  ip=$1
  host=$2
  hosts_line="$ip[[:space:]]$host"
  line_content=$(printf "%s\t%s\n" "$ip" "$host" )
  if [ -n "$(grep -P $hosts_line $ETC_HOSTS)" ]; then 
    echo "$line_content ya existe: $(grep $host $ETC_HOSTS | awk '{print $1}' )"
  else
    echo "Agregando $line_content a $ETC_HOSTS"
    sudo echo  "$line_content" >> $ETC_HOSTS;
  fi
  tput cnorm;
}
#
#===================================================================
# Función para dar de baja IP's o Host's
#===================================================================
#
function baja(){
  ip=$1 
  host=$2 
  hosts_line="$ip[[:space:]]$host"
  line_content=$(printf "%s\t%s\n" "$ip" "$host")
  if [ -n "$(grep -P $hosts_line $ETC_HOSTS)" ]; then
    echo "$line_content Removiendo de $ETC_HOSTS"
    sudo sed -i".bak" "/$hosts_line/d" $ETC_HOSTS
  else
    echo "$hosts_line no existe en $ETC_HOSTS";
  fi
  tput cnorm;
}
#
#===================================================================
# Función para remplazar, se requiere 4 argumentos.
#===================================================================
#
function remplazo(){
  ip=$1
  host=$2
  ipN=$3
  hostN=$4
  hosts_line="$ip[[:space:]]$host"
  line_content=$(printf "%s\t%s\n" "$ip" "$host")
  hosts_lineN="$ipN[[:space:]]$hostN"
  line_contentN=$(printf "%s\t%s\n" "$ipN" "$hostN")
  if [ -n "$(grep -P $hosts_line $ETC_HOSTS)" ]; then
    echo "$line_content Haciendo cambio en $ETC_HOSTS"
    sudo sed -i".bak" "/$hosts_line/d" $ETC_HOSTS;
    sudo echo "$line_contentN" >> $ETC_HOSTS
  else
    echo "$hosts_line no existe en $ETC_HOSTS";
  fi
  tput cnorm;
}
#
#===================================================================
# Gestión de parametros para el script 
#===================================================================
#
parameter_counter=0; while getopts "a:b:c:d:f:e:i:j:h:" arg; do 
  case $arg in 
    e) exploration_mode=$OPTARG; let parameter_counter+=1;;
    i) ip_output=$OPTARG; let parameter_counter+=1;;
    j) host_output=$OPTARG; let parameter_counter+=1;;
    a) Cambios_mode=$OPTARG; let parameter_counter+=1;;
    b) add_dev_host=$OPTARG; let parameter_counter+=1;;
    c) add_dev_ip=$OPTARG; let parameter_counter+=1;;
    d) del_dev_host=$OPTARG; let parameter_counter+=1;;
    f) del_dev_ip=$OPTARG; let parameter_counter+=1;;
    h) helpPanel;;

  esac
done
tput civis
#
#===================================================================
# Gestión del flujo del script
#===================================================================
#
if [ $parameter_counter -eq 0 ]; then
  helpPanel
else
  if [ "$(echo $exploration_mode)" == "busqueda_IP" ]; then
    if [ "$ip_output" ]; then
      search_IP $ip_output
    else
     helpPanel
    fi
 elif [ "$(echo $exploration_mode)" == "busqueda_HOST" ]; then
    if [ "$host_output" ]; then
      search_HOST $host_output
    else
     helpPanel
    fi
  elif [ "$(echo $Cambios_mode)" == "alta" ]; then
    if [ "$add_dev_host" ] && [ "$add_dev_ip" ]; then 
      alta $add_dev_host $add_dev_ip
    else
      helpPanel
    fi
  elif [ "$(echo $Cambios_mode)" == "baja" ]; then
    if [ "$del_dev_host" ] || [ "$del_dev_ip" ]; then
      baja $del_dev_host $del_dev_ip
    else 
      helpPanel
    fi
  elif [ "$(echo $Cambios_mode)" == "remplazo" ]; then
    if [ "$add_dev_host" ] && [ "$add_dev_ip" ] && [ "$del_dev_host" ] && [ "$del_dev_ip" ]; then
      remplazo $add_dev_host $add_dev_ip $del_dev_host $del_dev_ip
    else
      helpPanel
    fi
  fi 
fi
