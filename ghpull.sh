#!/bin/bash

REPO_USER="MicFedorov"
REPO_NAME="scripts"
BRANCH="main"

API_URL="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents"

echo "Получаю список файлов из GitHub ($REPO_USER/$REPO_NAME)..."
echo

# Получаем список файлов
FILES=$(curl -s "$API_URL" | grep '"name"' | sed 's/.*"name": "\(.*\)".*/\1/')

if [ -z "$FILES" ]; then
    echo "Ошибка: не удалось получить список файлов."
    exit 1
fi

# Показываем нумерованный список
i=1
declare -a ARRAY
echo "Список файлов:"
echo "---------------------------------"
echo " 0) Выход"
for f in $FILES; do
    echo " $i) $f"
    ARRAY[$i]=$f
    i=$((i+1))
done
echo " $i) Exit"
echo "---------------------------------"
echo

# Просим выбрать
read -p "Введите номер файла для скачивания: " NUM

FILE="${ARRAY[$NUM]}"

if [ -z "$FILE" ]; then
    echo "Ошибка: неверный номер."
    exit 1
fi

RAW_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$FILE"

echo "Скачиваю: $FILE"
echo "URL: $RAW_URL"
echo

curl -L -o "$FILE" "$RAW_URL"

if [ $? -eq 0 ]; then
    echo "Готово! Файл сохранён: $FILE"
else
    echo "Ошибка при скачивании."
fi
