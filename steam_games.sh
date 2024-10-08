#!/bin/bash

# Цветовые коды
TEAL='\033[38;5;38m'  # Цвет #5FAFBA
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Без цвета

# Файл для хранения пути к папке steamapps
pathFile="$HOME/.steam_steamapps_path"

# Функция для поиска папки steamapps
find_steam_apps_path() {
    find / -type d -name "steamapps" 2>/dev/null
}

# Проверка, существует ли файл с путем
if [[ -f "$pathFile" ]]; then
    steamAppsPath=$(cat "$pathFile")
else
    # Поиск папки steamapps
    steamAppsPath=$(find_steam_apps_path | head -n 1)
    
    # Проверка существования папки
    if [[ -z "$steamAppsPath" ]] || [[ ! -d "$steamAppsPath" ]]; then
        echo -e "${RED}    Папка steamapps не найдена.${NC}"
        exit 1
    fi
    
    # Сохранение найденного пути в файл
    echo "$steamAppsPath" > "$pathFile"
fi

# Проверка, запущен ли Steam
if ! pgrep -x "steam" > /dev/null; then
    read -p "Steam не запущен. Хотите запустить его? (y/n): " startSteam
    if [[ "$startSteam" == "y" ]]; then
        echo -e "${GREEN}    Запуск Steam...${NC}"
        nohup steam &>/dev/null &  # Запускаем Steam в фоновом режиме с nohup
    else
        echo -e "${RED}    Выход из скрипта.${NC}"
        exit 1
    fi
fi

# Функция для скрытия окон Steam
hide_steam_windows() {
    while true; do
        # Скрываем окно "Вход в Steam", если оно открыто
        if wmctrl -l | grep -q "Вход в Steam"; then
            wmctrl -r "Вход в Steam" -b add,hidden
        fi

        # Скрываем окно "Steam", если оно открыто
        if wmctrl -l | grep -q "Steam"; then
            wmctrl -r "Steam" -b add,hidden
        fi

        # Задержка перед следующей проверкой
        sleep 1
    done
}

# Запуск функции скрытия окон в фоновом режиме
hide_steam_windows &

# Ожидание появления окна Steam
while ! wmctrl -l | grep -q "Steam"; do
    echo -e "${YELLOW}    Ожидание запуска Steam...${NC}"
    sleep 1
done

# Извлечение названий игр и их идентификаторов
declare -a games
declare -a ids
index=0

while IFS= read -r line; do
    games+=("$line")
    ids+=("$index")
    ((index++))
done < <(find "$steamAppsPath" -name "*.acf" -exec grep -oP '"name"\s*"\K[^"]+' {} \;)

# Вывод списка игр с идентификаторами
echo -e "${TEAL} Список игр в Steam:${NC}"
echo "----------------------------"
for i in "${!games[@]}"; do
    printf "  %-3s: %s\n" "$i" "${games[$i]}"
done
echo "----------------------------"

# Массив запросов
declare -a prompts=(
    "Введите номер игры для запуска: "
    "Выберите игру для запуска : "
    "Какую игру вы предпочтёте? : "
)

# Случайный выбор запроса
randomPrompt=${prompts[$RANDOM % ${#prompts[@]}]}

# Запрос выбора игры
read -p "  $randomPrompt" choice

# Проверка корректности выбора
if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#games[@]}" ]; then
    gameName="${games[$choice]}"
    
    # Получение App ID из соответствующего файла appmanifest
    appId=$(find "$steamAppsPath" -name "appmanifest_*.acf" -exec grep -oP '"appid"\s*"\K[0-9]+' {} \; | sed -n "$((choice + 1))p")

    if [[ -n "$appId" ]]; then
        echo -e "${GREEN}    Запуск игры: $gameName (App ID: $appId)${NC}"
        steam steam://rungameid/$appId
    else
        echo -e "${RED}    Не удалось найти App ID для игры: $gameName${NC}"
    fi
else
    echo -e "${RED}    Некорректный выбор. Пожалуйста, введите номер из списка.${NC}"
    exit 1
fi
