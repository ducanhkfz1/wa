#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PATH="$PATH:/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin"

echo -e "\033[96m[BAOTUE] Dang khoi dong trinh cai dat da CloudPhone (Auto Yes)...\033[0m"

# Cap nhat repo & goi co ban
yes | pkg update -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>/dev/null || apt-get update -y
yes | pkg upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>/dev/null || true
pkg install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" python curl 2>/dev/null || apt-get install -y python curl

# Cai dat requests theo nhieu phuong an de tuong thich moi phien ban Termux/CloudPhone
pip install --break-system-packages --no-cache-dir requests 2>/dev/null || \
python -m pip install --break-system-packages --no-cache-dir requests 2>/dev/null || \
pkg install -y python-requests 2>/dev/null || \
pip install --no-cache-dir requests 2>/dev/null || true

# Cap quyen bo nho neu co (auto yes, khong gay loi neu thiet bi chan)
printf "y\n" | termux-setup-storage >/dev/null 2>&1 || true
sleep 1

# Xac dinh thu muc luu tool tuong thich (uu tien /sdcard/Download, du phong ~)
TARGET_DIR="/sdcard/Download"
mkdir -p "$TARGET_DIR" 2>/dev/null || true
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME"
fi

echo -e "\033[96m[BAOTUE] Dang tai baotue.py ve $TARGET_DIR...\033[0m"
curl -L -s -o "$TARGET_DIR/baotue.py" https://raw.githubusercontent.com/baotuecoder999/BTHub/main/baotue.py

# Luu them 1 ban du phong o ~ neu tai vao /sdcard/Download
if [ "$TARGET_DIR" != "$HOME" ]; then
    cp -f "$TARGET_DIR/baotue.py" "$HOME/baotue.py" 2>/dev/null || true
fi

# Tao lenh tat baotue (tu dong dung su neu co, khong bat buoc neu khong root)
cat << 'EOF' > /data/data/com.termux/files/usr/bin/baotue
#!/bin/bash
export PATH="$PATH:/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin"
export TERM=xterm-256color

if [ -f "/sdcard/Download/baotue.py" ]; then
    SCRIPT_PATH="/sdcard/Download/baotue.py"
    WORK_DIR="/sdcard/Download"
else
    SCRIPT_PATH="$HOME/baotue.py"
    WORK_DIR="$HOME"
fi

cd "$WORK_DIR" 2>/dev/null || true
if command -v su >/dev/null 2>&1 && su -c "id" >/dev/null 2>&1; then
    su -c "export PATH=$PATH:/data/data/com.termux/files/usr/bin && export TERM=xterm-256color && cd \"$WORK_DIR\" && python \"$SCRIPT_PATH\""
else
    python "$SCRIPT_PATH"
fi
EOF
chmod +x /data/data/com.termux/files/usr/bin/baotue 2>/dev/null || true

echo -e "\033[92m[BAOTUE] Cai dat hoan tat tren thiet bi! Co the go 'baotue' hoac chay lenh khoi dong.\033[0m"
