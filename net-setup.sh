#!/bin/bash

printf "Автоматический \e[9mудовлетворитель\e[0m установщик IP адреса v 0.1a"
printf "\n\n"

# Имя скрипта для конфига
SCRIPT_NAME=$(basename "$0" .sh)
CONFIG_FILE="$HOME/.$SCRIPT_NAME"

# Функция помощи
show_help() {
    echo "Использование: $0 <режим>"
    echo "  Режимы:"
    echo "    dyn    - Динамический IP (DHCP)"
    echo "    stat   - Статический IP из файла $CONFIG_FILE"
    echo ""
    echo "Формат конфига $CONFIG_FILE:"
    echo "Создайте конфиг: sudo vi /root/.net-setup"
    echo "  IP      192.168.1.100/24"
    echo "  GATE    192.168.1.1"
    echo "  DNS     8.8.8.8 1.1.1.1"
    echo "  BROAD   192.168.1.255"
    echo ""
    echo "Если будут проблемы с выходом из vi то:"
    echo ":!ps | grep vi | grep -v grep | awk '{print \$1}' | xargs kill -9"
    echo ""
    echo "Если параметры отсутствуют, они вычисляются автоматически из IP"
}

# Функция для получения имени активного соединения
get_connection_name() {
    nmcli -t -f NAME connection show --active | head -n1
}

# Функция для вычисления параметров по умолчанию из IP
calculate_params() {
    local ip_cidr="$1"
    
    # Разделяем IP и маску
    local ip_base="${ip_cidr%/*}"
    local cidr="${ip_cidr#*/}"
    
    # Разбиваем IP на октеты
    IFS='.' read -r -a octets <<< "$ip_base"
    local base_net="${octets[0]}.${octets[1]}.${octets[2]}"
    
    # Вычисляем параметры если они не заданы в конфиге
    GATE="${GATE:-${base_net}.1}"
    BROAD="${BROAD:-${base_net}.255}"
    DNS="${DNS:-$GATE}"
}

# Функция чтения конфига
read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Ошибка: Конфиг $CONFIG_FILE не найден!"
        show_help
        exit 1
    fi
    
    # Читаем конфиг, игнорируя комментарии и пустые строки
    while IFS=$'\t' read -r key value; do
        # Пропускаем комментарии и пустые строки
        [[ "$key" =~ ^# ]] && continue
        [[ -z "$key" ]] && continue
        
        case "$key" in
            "IP") IP="$value" ;;
            "GATE") GATE="$value" ;;
            "DNS") DNS="$value" ;;
            "BROAD") BROAD="$value" ;;
        esac
    done < <(grep -v '^#' "$CONFIG_FILE" | sed '/^$/d')
    
    # Проверяем обязательный параметр IP
    if [[ -z "$IP" ]]; then
        echo "Ошибка: IP не указан в конфиге $CONFIG_FILE"
        exit 1
    fi
    
    # Вычисляем недостающие параметры
    calculate_params "$IP"
}

# Функция установки статического IP
set_static_ip() {
    local conn_name="$1"
    
    echo "Устанавливаю статический IP для соединения: $conn_name"
    echo "Параметры:"
    echo "  IP: $IP"
    echo "  Gateway: $GATE" 
    echo "  DNS: $DNS"
    echo "  Broadcast: $BROAD (вычисляется автоматически)"
    
    # Устанавливаем параметры через nmcli
    nmcli connection modify "$conn_name" \
        ipv4.method manual \
        ipv4.addresses "$IP" \
        ipv4.gateway "$GATE" \
        ipv4.dns "$DNS"
#    \
#        ipv4.broadcast "$BROAD"
    
    # Перезапускаем соединение
    nmcli connection down "$conn_name"
    nmcli connection up "$conn_name"
    
    echo "Статический IP успешно установлен!"
}

# Функция установки динамического IP
set_dynamic_ip() {
    local conn_name="$1"
    
    echo "Устанавливаю динамический IP (DHCP) для соединения: $conn_name"
    
    nmcli connection modify "$conn_name" \
        ipv4.method auto \
        ipv4.ignore-auto-dns no \
        ipv4.ignore-auto-routes no
    
    # Перезапускаем соединение
    nmcli connection down "$conn_name" 
    nmcli connection up "$conn_name"
    
    echo "Динамический IP успешно установлен!"
}

# Основной код
if [[ $# -ne 1 ]]; then
    show_help
    exit 1
fi

# Получаем имя активного соединения
CONNECTION=$(get_connection_name)
if [[ -z "$CONNECTION" ]]; then
    echo "Ошибка: Не найдено активное соединение!"
    exit 1
fi

echo "Работаем с соединением: $CONNECTION"

case "$1" in
    "dyn")
        set_dynamic_ip "$CONNECTION"
        ;;
    "stat") 
        read_config
        set_static_ip "$CONNECTION"
        ;;
    *)
        echo "Неизвестный режим: $1"
        show_help
        exit 1
        ;;
esac
