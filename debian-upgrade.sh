#!/bin/bash

# Debian Sürüm Yükseltme Scripti
# Bu script Debian 9'dan 12'ye kadar güvenli yükseltme sağlar

set -e  # Hata durumunda scripti durdur

# Renkli çıktı için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log dosyası
LOG_FILE="/var/log/debian-upgrade-$(date +%Y%m%d-%H%M%S).log"

# Fonksiyonlar
log_message() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error_message() {
    echo -e "${RED}[HATA]${NC} $1" | tee -a "$LOG_FILE"
}

warning_message() {
    echo -e "${YELLOW}[UYARI]${NC} $1" | tee -a "$LOG_FILE"
}

info_message() {
    echo -e "${BLUE}[BİLGİ]${NC} $1" | tee -a "$LOG_FILE"
}

# Root kontrolü
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_message "Bu script root yetkileri ile çalıştırılmalıdır!"
        echo "Lütfen 'sudo $0' komutu ile çalıştırın."
        exit 1
    fi
}

# Debian sürüm tespiti
get_debian_version() {
    if [[ -f /etc/debian_version ]]; then
        local version=$(cat /etc/debian_version)
        case $version in
            9.*|stretch*) echo "9" ;;
            10.*|buster*) echo "10" ;;
            11.*|bullseye*) echo "11" ;;
            12.*|bookworm*) echo "12" ;;
            *) 
                # /etc/os-release dosyasından kontrol et
                if [[ -f /etc/os-release ]]; then
                    local version_id=$(grep "VERSION_ID" /etc/os-release | cut -d'"' -f2)
                    echo "$version_id"
                else
                    echo "unknown"
                fi
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Sistem kontrolleri
system_checks() {
    log_message "Sistem kontrolleri başlatılıyor..."
    
    # Disk alanı kontrolü (en az 2GB boş alan)
    local free_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=2097152  # 2GB in KB
    
    if [[ $free_space -lt $required_space ]]; then
        error_message "Yetersiz disk alanı! En az 2GB boş alan gerekli."
        echo "Mevcut boş alan: $(($free_space/1024/1024))GB"
        exit 1
    fi
    
    # İnternet bağlantısı kontrolü
    if ! ping -c 3 deb.debian.org &>/dev/null; then
        error_message "İnternet bağlantısı yok veya Debian depolarına erişilemiyor!"
        exit 1
    fi
    
    # Çalışan paket yöneticisi kontrolü
    if pgrep -x "apt|apt-get|dpkg" > /dev/null; then
        error_message "Başka bir paket yöneticisi çalışıyor! Lütfen bekleyin veya sonlandırın."
        exit 1
    fi
    
    log_message "Sistem kontrolleri tamamlandı."
}

# Sources.list yedekleme
backup_sources() {
    local backup_file="/etc/apt/sources.list.backup-$(date +%Y%m%d-%H%M%S)"
    cp /etc/apt/sources.list "$backup_file"
    log_message "Sources.list yedeklendi: $backup_file"
}

# Sources.list güncelleme
update_sources_list() {
    local target_version=$1
    local sources_content=""
    
    case $target_version in
        "10")
            sources_content="deb http://deb.debian.org/debian buster main contrib non-free
deb-src http://deb.debian.org/debian buster main contrib non-free
deb http://deb.debian.org/debian buster-updates main contrib non-free
deb-src http://deb.debian.org/debian buster-updates main contrib non-free
deb http://security.debian.org/debian-security/ buster/updates main contrib non-free
deb-src http://security.debian.org/debian-security/ buster/updates main contrib non-free"
            ;;
        "11")
            sources_content="deb http://deb.debian.org/debian bullseye main contrib non-free
deb-src http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb-src http://deb.debian.org/debian bullseye-backports main contrib non-free
deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free
deb-src http://security.debian.org/debian-security/ bullseye-security main contrib non-free"
            ;;
        "12")
            sources_content="deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware"
            ;;
    esac
    
    echo "$sources_content" > /etc/apt/sources.list
    log_message "Sources.list güncellendi (Debian $target_version)"
}

# Upgrade işlemi
perform_upgrade() {
    local target_version=$1
    
    log_message "Debian $target_version'e yükseltme başlatılıyor..."
    
    # Paket listelerini güncelle
    log_message "Paket listeleri güncelleniyor..."
    apt update 2>&1 | tee -a "$LOG_FILE"
    
    # Mevcut sistemde minimal upgrade
    log_message "Minimal upgrade yapılıyor..."
    apt upgrade -y 2>&1 | tee -a "$LOG_FILE"
    
    # Tam yükseltme
    log_message "Tam dağıtım yükseltmesi yapılıyor..."
    
    # DEBIAN_FRONTEND=noninteractive ile otomatik mod
    DEBIAN_FRONTEND=noninteractive apt full-upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        2>&1 | tee -a "$LOG_FILE"
    
    # Gereksiz paketleri temizle
    log_message "Gereksiz paketler temizleniyor..."
    apt autoremove -y 2>&1 | tee -a "$LOG_FILE"
    apt autoclean 2>&1 | tee -a "$LOG_FILE"
    
    log_message "Debian $target_version yükseltmesi tamamlandı!"
}

# Ana menü
show_menu() {
    local current_version=$1
    local max_version=""
    local options=()
    
    case $current_version in
        "9")
            max_version="12"
            options=("10" "11" "12")
            ;;
        "10")
            max_version="12"
            options=("11" "12")
            ;;
        "11")
            max_version="12"
            options=("12")
            ;;
        "12")
            echo -e "${GREEN}Sisteminiz zaten güncel! (Debian 12)${NC}"
            exit 0
            ;;
        *)
            error_message "Desteklenmeyen Debian sürümü: $current_version"
            exit 1
            ;;
    esac
    
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    Debian Sürüm Yükseltme Scripti${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo ""
    echo -e "Mevcut sürüm: ${GREEN}Debian $current_version${NC}"
    echo ""
    echo "Yükseltme seçenekleri:"
    
    for i in "${!options[@]}"; do
        echo "$((i+1)). Debian ${options[i]}'e yükselt"
    done
    
    echo "0. Çıkış"
    echo ""
    
    while true; do
        read -p "Seçiminizi yapın (0-${#options[@]}): " choice
        
        if [[ $choice == "0" ]]; then
            echo "Çıkılıyor..."
            exit 0
        elif [[ $choice =~ ^[1-9]$ ]] && [[ $choice -le ${#options[@]} ]]; then
            local target_version=${options[$((choice-1))]}
            
            echo ""
            warning_message "Debian $current_version'dan Debian $target_version'e yükseltme yapılacak!"
            echo ""
            echo -e "${RED}UYARI: Bu işlem sisteminizi kalıcı olarak değiştirecektir!${NC}"
            echo -e "${RED}Devam etmeden önce önemli verilerinizi yedeklediğinizden emin olun!${NC}"
            echo ""
            
            read -p "Devam etmek istediğinizden emin misiniz? (y/N): " confirm
            
            if [[ $confirm =~ ^[Yy]$ ]]; then
                start_upgrade "$target_version"
                break
            else
                echo "İşlem iptal edildi."
                exit 0
            fi
        else
            echo "Geçersiz seçim! Lütfen 0-${#options[@]} arasında bir sayı girin."
        fi
    done
}

# Yükseltme başlatma
start_upgrade() {
    local target_version=$1
    
    log_message "Debian $target_version yükseltme işlemi başlatılıyor..."
    log_message "Log dosyası: $LOG_FILE"
    
    # Sistem kontrolleri
    system_checks
    
    # Sources.list yedekleme
    backup_sources
    
    # Sources.list güncelleme
    update_sources_list "$target_version"
    
    # Yükseltme işlemi
    perform_upgrade "$target_version"
    
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  YÜKSELTME BAŞARIYLA TAMAMLANDI!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "Yeni sürüm: ${GREEN}Debian $target_version${NC}"
    echo -e "Log dosyası: ${BLUE}$LOG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}Sistemin tamamen güncellenmesi için yeniden başlatma önerilir.${NC}"
    echo ""
    
    read -p "Şimdi yeniden başlatmak ister misiniz? (y/N): " reboot_choice
    if [[ $reboot_choice =~ ^[Yy]$ ]]; then
        log_message "Sistem yeniden başlatılıyor..."
        reboot
    else
        echo "Yeniden başlatma işlemi manuel olarak yapılacak."
    fi
}

# Ana script başlangıcı
main() {
    # Root kontrolü
    check_root
    
    # Debian sürüm tespiti
    current_version=$(get_debian_version)
    
    if [[ $current_version == "unknown" ]]; then
        error_message "Bu script sadece Debian sistemlerde çalışır!"
        exit 1
    fi
    
    # Ana menüyü göster
    show_menu "$current_version"
}

# Interrupt sinyali yakalama (Ctrl+C)
trap 'echo -e "\n${RED}İşlem kullanıcı tarafından iptal edildi.${NC}"; exit 1' INT

# Script'i başlat
main "$@"
