#!/usr/bin/env bash

# Get script directory
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

NAMESPACE="ctos"

# main directories
CONFIG_DIR="/etc/$NAMESPACE"
INSTALL_DIR="/opt/$NAMESPACE"

# configs
GREETER_CONFIG_FILEPATH="$CONFIG_DIR/greeter.config.json"
GREETER_KWIN_FILEPATH="$CONFIG_DIR/greeter.kwin.conf"

FRESH_INSTALL=1
if [[ -d "$CONFIG_DIR" ]]; then
  FRESH_INSTALL=0
fi

graceful_exit() {
  echo
  echo
  echo -e "[EXIT] Process interrupted or failed."
  exit 1
}

install_dependencies() {
  echo "[DEPS] Checking dependencies..."
  echo

  # Пакеты из официальных репозиториев
  local pacman_packages=(
    "greetd"
    "rsync"
    "python"
    "kwin"
  )

  # Пакеты из AUR
  local aur_packages=(
    "quickshell-git"
    "ttf-jetbrains-mono-nerd"
  )

  # Определяем AUR хелпер
  local aur_helper=""
  for helper in yay paru; do
    if command -v "$helper" &>/dev/null; then
      aur_helper="$helper"
      break
    fi
  done

  # Устанавливаем pacman пакеты
  local missing_pacman=()
  for pkg in "${pacman_packages[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      missing_pacman+=("$pkg")
    else
      echo "[DEPS]    ok: $pkg"
    fi
  done

  if [[ ${#missing_pacman[@]} -gt 0 ]]; then
    echo "[DEPS] Installing: ${missing_pacman[*]}"
    sudo pacman -S --needed --noconfirm "${missing_pacman[@]}"
  fi

  # Устанавливаем AUR пакеты
  local missing_aur=()
  for pkg in "${aur_packages[@]}"; do
    # Проверяем по базовому имени без суффикса -git
    local base_pkg="${pkg%-git}"
    if ! pacman -Qi "$pkg" &>/dev/null && ! pacman -Qi "$base_pkg" &>/dev/null; then
      missing_aur+=("$pkg")
    else
      echo "[DEPS]    ok: $pkg"
    fi
  done

  if [[ ${#missing_aur[@]} -gt 0 ]]; then
    if [[ -z "$aur_helper" ]]; then
      echo
      echo "[WARN] AUR helper (yay/paru) not found. Install manually:"
      for pkg in "${missing_aur[@]}"; do
        echo "       $pkg"
      done
      echo
    else
      echo "[DEPS] Installing from AUR via $aur_helper: ${missing_aur[*]}"
      "$aur_helper" -S --needed --noconfirm "${missing_aur[@]}"
    fi
  fi

  echo
  echo "[DEPS] Done."
  echo
}

detect_compositor() {
  if [[ "$XDG_SESSION_TYPE" != "wayland" ]]; then
    echo
    echo "[ERROR] CTOS only supports Wayland sessions."
    exit 1
  fi
}

generate_greeter_config() {
  local user="$1"
  local monitor="$2"

  cat <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/alexsesser/ctOS/main/schema/greeter.schema.json",
  "user": "$user",
  "monitor": "$monitor",
  "fontFamily": "JetBrainsMono Nerd Font",
  "fakeIdentity": {
    "id": "XYZ-843",
    "class": "L5_PROV",
    "fullName": "Blume Admin"
  },
  "fakeStatus": {
    "env": "Workstation",
    "node": "109.389.013.301"
  },
  "modes": {
    "greetd": {
      "animations": "all",
      "exit": ["pkill", "kwin_wayland"],
      "launch": ["startplasma-wayland"]
    },
    "lockd": {
      "animations": "reduced"
    },
    "test": {
      "animations": "all"
    }
  }
}
EOF
}

generate_kwin_conf() {
  local monitor="$1"

  cat <<EOF
#!/bin/sh
export XDG_RUNTIME_DIR="/run/user/\$(id -u greeter)"
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export CTOS_MODE=greetd

exec /usr/bin/kwin_wayland \\
    --width 1920 \\
    --height 1080 \\
    --exit-with-session="/usr/bin/quickshell --path $INSTALL_DIR/greeter.qml" \\
    --no-lockscreen \\
    --no-global-shortcuts \\
    --no-kactivities \\
    --inputmethod /usr/lib/qt6/plugins/org.kde.kwin.inputmethod.empty.so
EOF
}

# Записывает файл всегда (создаёт или перезаписывает)
write_file() {
  local contents="$1"
  local target_path="$2"
  local existed=0

  [[ -f "$target_path" ]] && existed=1

  sudo mkdir -p "$(dirname "$target_path")"

  if [[ -z "$contents" ]]; then
    echo
    echo "[!][ERROR] empty input for $target_path"
    exit 1
  fi

  echo "$contents" | sudo tee "$target_path" >/dev/null

  if [[ $? -eq 0 ]]; then
    if [[ $existed -eq 1 ]]; then
      echo "[ITEM] updated: $target_path"
    else
      echo "[ITEM]   added: $target_path"
    fi
    return 0
  fi

  echo "[!][ERROR] failed to write: $target_path"
  exit 1
}

# Создаёт файл только если не существует (для пользовательских конфигов)
ensure_exists() {
  local input="$1"
  local target_path="$2"

  if [[ -f "$target_path" ]]; then
    echo "[ITEM]   found: $target_path (skipping)"
    return 0
  fi

  sudo mkdir -p "$(dirname "$target_path")"

  local contents=""

  if [[ -f "$input" ]]; then
    contents=$(cat "$input")
  else
    contents="$input"
  fi

  if [[ -z "$contents" ]]; then
    echo
    echo "[!][ERROR] empty input for $target_path"
    exit 1
  fi

  echo "$contents" | sudo tee "$target_path" >/dev/null

  if [[ $? -eq 0 ]]; then
    echo "[ITEM]   added: $target_path"
    return 0
  fi

  echo "[!][ERROR] failed to write: $target_path"
  exit 1
}

function detect_monitor() {
  # Пытаемся определить монитор через kscreen
  DEFAULT_MONITOR=$(kscreen-doctor -o 2>/dev/null | grep -oP '(?<=Output: )\S+' | head -1)

  # Fallback через wlr-randr если установлен
  if [[ -z "$DEFAULT_MONITOR" ]]; then
    DEFAULT_MONITOR=$(wlr-randr 2>/dev/null | grep -oP '^\S+' | head -1)
  fi

  # Fallback через /sys
  if [[ -z "$DEFAULT_MONITOR" ]]; then
    DEFAULT_MONITOR=$(ls /sys/class/drm/ | grep -oP '(?<=card\d-)\S+' | head -1)
  fi
}

function run_setup_wizard() {
  echo
  echo "[CTOS INSTALLER — KDE/Arch]"
  echo

  DEFAULT_USER=$(whoami)
  read -p "[Q] ENTER TARGET USER [$DEFAULT_USER]: " SELECTED_USER
  SELECTED_USER=${SELECTED_USER:-$DEFAULT_USER}

  detect_monitor
  MONITOR_PROMPT=${DEFAULT_MONITOR:+ [$DEFAULT_MONITOR]}
  read -p "[Q] ENTER PRIMARY MONITOR$MONITOR_PROMPT: " SELECTED_MONITOR
  SELECTED_MONITOR=${SELECTED_MONITOR:-$DEFAULT_MONITOR}

  echo
  echo "[BASIC SETTINGS]"
  echo "COMPOSITOR=kwin_wayland"
  echo "USER=$SELECTED_USER"
  echo "MONITOR=$SELECTED_MONITOR"
  echo

  read -rp "[Q] Proceed with installation? (y/n) "

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo
    echo "[EXIT] Installation aborted."
    exit 1
  fi
}

function install_greeter_kwin_conf() {
  write_file "$(generate_kwin_conf "$SELECTED_MONITOR")" "$GREETER_KWIN_FILEPATH"

  # Делаем исполняемым — greetd запускает его как скрипт
  sudo chmod +x "$GREETER_KWIN_FILEPATH"
  echo "[ITEM]    chmod: $GREETER_KWIN_FILEPATH (executable)"
}

function sync_project_files() {
  sudo mkdir -p "$INSTALL_DIR"

  sudo rsync -ahq \
    --exclude=".git" \
    --exclude=".assets" \
    --exclude="themes" \
    --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r \
    "$SCRIPT_DIR/" "$INSTALL_DIR"

  if [[ "$FRESH_INSTALL" -eq 1 ]]; then
    echo "[ITEM]   added: $INSTALL_DIR"
  else
    echo "[ITEM] updated: $INSTALL_DIR"
  fi
}

function check_greetd_config() {
  local greetd_config="/etc/greetd/config.toml"

  if [[ ! -f "$greetd_config" ]]; then
    echo
    echo "[WARN] /etc/greetd/config.toml not found. Is greetd installed?"
    echo "       Install with: sudo pacman -S greetd"
    return
  fi

  # Проверяем что greetd уже указывает на наш скрипт
  if grep -q "$GREETER_KWIN_FILEPATH" "$greetd_config"; then
    echo "[ITEM]    ok: greetd already configured"
  else
    echo
    echo "[WARN] greetd не настроен на ctOS."
    echo "       Добавь в $greetd_config:"
    echo
    echo "  [default_session]"
    echo "  command = \"$GREETER_KWIN_FILEPATH\""
    echo "  user = \"greeter\""
    echo
  fi
}

# --------------------------------------------------------------------------------
# SECTION Main
# --------------------------------------------------------------------------------

trap graceful_exit ERR SIGINT SIGTERM

install_dependencies

detect_compositor

# Читаем существующий конфиг чтобы сохранить user/monitor при обновлении
if [[ -f "$GREETER_CONFIG_FILEPATH" ]]; then
  EXISTING_USER=$(python3 -c "import json,sys; d=json.load(open('$GREETER_CONFIG_FILEPATH')); print(d.get('user',''))" 2>/dev/null)
  EXISTING_MONITOR=$(python3 -c "import json,sys; d=json.load(open('$GREETER_CONFIG_FILEPATH')); print(d.get('monitor',''))" 2>/dev/null)
fi

if [[ "$FRESH_INSTALL" -eq 1 || ! -f "$GREETER_CONFIG_FILEPATH" ]]; then
  # Первая установка — спрашиваем пользователя
  run_setup_wizard
  sudo mkdir -p "$CONFIG_DIR"
  write_file "$(generate_greeter_config "$SELECTED_USER" "$SELECTED_MONITOR")" "$GREETER_CONFIG_FILEPATH"
else
  # Обновление — перезаписываем конфиг, сохраняя user и monitor
  SELECTED_USER="${EXISTING_USER:-$(whoami)}"
  SELECTED_MONITOR="${EXISTING_MONITOR:-}"
  detect_monitor
  SELECTED_MONITOR="${SELECTED_MONITOR:-$DEFAULT_MONITOR}"
  write_file "$(generate_greeter_config "$SELECTED_USER" "$SELECTED_MONITOR")" "$GREETER_CONFIG_FILEPATH"
fi

echo

install_greeter_kwin_conf

sync_project_files

check_greetd_config

echo
echo "[EXIT] SUCCESSFULLY COMPLETED."
