# 🚀 Debian Version Upgrade Script / Debian Sürüm Yükseltme Scripti

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-9%20to%2012-red.svg)](https://www.debian.org/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

## 🌟 Overview / Genel Bakış

**English**: This script provides a safe and automated way to upgrade Debian systems from version 9 to 12. It handles all the necessary steps including repository updates, package management, and system checks.

**Türkçe**: Bu script, Debian sistemlerini 9. sürümden 12. sürüme kadar güvenli ve otomatik bir şekilde yükseltmenizi sağlar. Depo güncellemeleri, paket yönetimi ve sistem kontrollerini içeren tüm gerekli adımları yönetir.

---

## 📋 Table of Contents / İçindekiler

- [Features / Özellikler](#-features--özellikler)
- [Supported Versions / Desteklenen Sürümler](#-supported-versions--desteklenen-sürümler)
- [Prerequisites / Gereksinimler](#-prerequisites--gereksinimler)
- [Installation / Kurulum](#-installation--kurulum)
- [Usage / Kullanım](#-usage--kullanım)
- [Safety Features / Güvenlik Özellikleri](#-safety-features--güvenlik-özellikleri)
- [Troubleshooting / Sorun Giderme](#-troubleshooting--sorun-giderme)
- [Contributing / Katkıda Bulunma](#-contributing--katkıda-bulunma)
- [License / Lisans](#-license--lisans)

---

## ✨ Features / Özellikler

### 🔧 **English Features:**
- 🎯 **Automatic Version Detection**: Detects current Debian version automatically
- 🛡️ **Safety Checks**: Validates system requirements before starting
- 📦 **Repository Management**: Automatically updates sources.list for target version
- 💾 **Backup System**: Creates automatic backups of critical files
- 📊 **Progress Monitoring**: Real-time progress updates with colored output
- 📝 **Detailed Logging**: Comprehensive logs for troubleshooting
- 🔄 **Interactive Menu**: User-friendly selection interface
- ⚡ **Non-interactive Mode**: Automated upgrade process
- 🧹 **Cleanup**: Removes unnecessary packages after upgrade

### 🔧 **Türkçe Özellikler:**
- 🎯 **Otomatik Sürüm Tespiti**: Mevcut Debian sürümünü otomatik algılar
- 🛡️ **Güvenlik Kontrolleri**: Başlamadan önce sistem gereksinimlerini doğrular
- 📦 **Depo Yönetimi**: Hedef sürüm için sources.list'i otomatik günceller
- 💾 **Yedekleme Sistemi**: Kritik dosyaların otomatik yedeklerini oluşturur
- 📊 **İlerleme Takibi**: Renkli çıktı ile gerçek zamanlı ilerleme güncellemeleri
- 📝 **Detaylı Log Tutma**: Sorun giderme için kapsamlı loglar
- 🔄 **Etkileşimli Menü**: Kullanıcı dostu seçim arayüzü
- ⚡ **Etkileşimsiz Mod**: Otomatik yükseltme süreci
- 🧹 **Temizlik**: Yükseltme sonrası gereksiz paketleri kaldırır

---

## 🎯 Supported Versions / Desteklenen Sürümler

| Current Version<br>Mevcut Sürüm | Available Upgrades<br>Mevcut Yükseltmeler |
|:---:|:---:|
| 🔢 **Debian 9** (Stretch) | ➡️ 10, 11, 12 |
| 🔢 **Debian 10** (Buster) | ➡️ 11, 12 |
| 🔢 **Debian 11** (Bullseye) | ➡️ 12 |
| ✅ **Debian 12** (Bookworm) | Already Updated / Zaten Güncel |

---

## ⚙️ Prerequisites / Gereksinimler

### 📋 **System Requirements / Sistem Gereksinimleri:**

- 🐧 **Operating System / İşletim Sistemi**: Debian 9, 10, 11
- 👤 **User Privileges / Kullanıcı Yetkileri**: Root access / Root erişimi
- 💽 **Free Disk Space / Boş Disk Alanı**: Minimum 2GB
- 🌐 **Internet Connection / İnternet Bağlantısı**: Required / Gerekli
- 🔧 **Package Manager / Paket Yöneticisi**: No other package managers running / Başka paket yöneticisi çalışmamalı

### 🔍 **Check Your System / Sisteminizi Kontrol Edin:**

```bash
# Check Debian version / Debian sürümünü kontrol edin
cat /etc/debian_version

# Check available disk space / Mevcut disk alanını kontrol edin
df -h /

# Check internet connectivity / İnternet bağlantısını kontrol edin
ping -c 3 deb.debian.org

# Check running package managers / Çalışan paket yöneticilerini kontrol edin
ps aux | grep -E "(apt|dpkg)" | grep -v grep
```

---

## 📥 Installation / Kurulum

### 🚀 **Quick Install / Hızlı Kurulum:**

```bash
# Download the script / Scripti indirin
wget https://raw.githubusercontent.com/yourusername/debian-upgrade-script/main/debian-upgrade.sh

# Make it executable / Çalıştırılabilir yapın
chmod +x debian-upgrade.sh

# Run with root privileges / Root yetkileri ile çalıştırın
sudo ./debian-upgrade.sh
```

### 🔄 **Alternative Methods / Alternatif Yöntemler:**

#### **Method 1: Git Clone / Git ile Klonlama**
```bash
# Clone repository / Depoyu klonlayın
git clone https://github.com/yourusername/debian-upgrade-script.git

# Navigate to directory / Dizine gidin
cd debian-upgrade-script

# Make executable / Çalıştırılabilir yapın
chmod +x debian-upgrade.sh

# Run script / Scripti çalıştırın
sudo ./debian-upgrade.sh
```

#### **Method 2: Manual Download / Manuel İndirme**
```bash
# Create directory / Dizin oluşturun
mkdir ~/debian-upgrade && cd ~/debian-upgrade

# Download with curl / curl ile indirin
curl -O https://raw.githubusercontent.com/yourusername/debian-upgrade-script/main/debian-upgrade.sh

# Set permissions / İzinleri ayarlayın
chmod +x debian-upgrade.sh

# Execute / Çalıştırın
sudo ./debian-upgrade.sh
```

---

## 🎮 Usage / Kullanım

### 🖥️ **Interactive Mode / Etkileşimli Mod:**

```bash
# Run the script / Scripti çalıştırın
sudo ./debian-upgrade.sh
```

**Example Output / Örnek Çıktı:**
```
===========================================
    Debian Sürüm Yükseltme Scripti
===========================================

Mevcut sürüm: Debian 10

Yükseltme seçenekleri:
1. Debian 11'e yükselt
2. Debian 12'e yükselt
0. Çıkış

Seçiminizi yapın (0-2): 
```

### 📋 **Step-by-Step Process / Adım Adım Süreç:**

1. **🔍 System Detection / Sistem Tespiti**
   ```
   [2024-06-03 10:30:15] Sistem kontrolleri başlatılıyor...
   [2024-06-03 10:30:16] Debian 10 tespit edildi
   ```

2. **✅ Pre-upgrade Checks / Yükseltme Öncesi Kontroller**
   ```
   [BİLGİ] Disk alanı kontrolü: ✅ Yeterli alan mevcut
   [BİLGİ] İnternet bağlantısı: ✅ Bağlantı başarılı
   [BİLGİ] Paket yöneticisi: ✅ Başka process çalışmıyor
   ```

3. **💾 Backup Creation / Yedek Oluşturma**
   ```
   [2024-06-03 10:30:20] Sources.list yedeklendi: /etc/apt/sources.list.backup-20240603-103020
   ```

4. **🔄 Repository Update / Depo Güncellemesi**
   ```
   [2024-06-03 10:30:25] Sources.list güncellendi (Debian 11)
   [2024-06-03 10:30:30] Paket listeleri güncelleniyor...
   ```

5. **📦 Package Upgrade / Paket Yükseltmesi**
   ```
   [2024-06-03 10:35:45] Minimal upgrade yapılıyor...
   [2024-06-03 10:45:20] Tam dağıtım yükseltmesi yapılıyor...
   ```

6. **🧹 Cleanup / Temizlik**
   ```
   [2024-06-03 11:15:30] Gereksiz paketler temizleniyor...
   [2024-06-03 11:16:45] Debian 11 yükseltmesi tamamlandı!
   ```

---

## 🛡️ Safety Features / Güvenlik Özellikleri

### 🔒 **Built-in Protections / Yerleşik Korumalar:**

- **🔐 Root Check / Root Kontrolü**: Ensures script runs with proper privileges / Scriptin uygun yetkilerle çalıştığından emin olur
- **💾 Automatic Backup / Otomatik Yedekleme**: Creates timestamped backups / Zaman damgalı yedekler oluşturur
- **🌐 Connectivity Verification / Bağlantı Doğrulama**: Tests repository access / Depo erişimini test eder
- **💽 Space Validation / Alan Doğrulama**: Ensures sufficient disk space / Yeterli disk alanından emin olur
- **⚠️ Conflict Resolution / Çakışma Çözümü**: Handles package conflicts automatically / Paket çakışmalarını otomatik çözer

### 📋 **Backup Files / Yedek Dosyalar:**

```bash
# View backup files / Yedek dosyaları görüntüleyin
ls -la /etc/apt/sources.list.backup-*

# Restore from backup if needed / Gerekirse yedekten geri yükleyin
sudo cp /etc/apt/sources.list.backup-YYYYMMDD-HHMMSS /etc/apt/sources.list
```

### 📝 **Log Files / Log Dosyaları:**

```bash
# View recent logs / Son logları görüntüleyin
sudo tail -f /var/log/debian-upgrade-*.log

# Search for errors / Hataları arayın
sudo grep -i "error\|fail" /var/log/debian-upgrade-*.log
```

---

## 🔧 Troubleshooting / Sorun Giderme

### ❌ **Common Issues / Yaygın Sorunlar:**

#### **🚫 Permission Denied / İzin Reddedildi**
```bash
# Problem / Sorun:
bash: ./debian-upgrade.sh: Permission denied

# Solution / Çözüm:
chmod +x debian-upgrade.sh
sudo ./debian-upgrade.sh
```

#### **🌐 Network Issues / Ağ Sorunları**
```bash
# Problem / Sorun:
Could not resolve 'deb.debian.org'

# Solution / Çözüm:
# Check DNS settings / DNS ayarlarını kontrol edin
cat /etc/resolv.conf

# Test connectivity / Bağlantıyı test edin
ping 8.8.8.8
```

#### **💽 Insufficient Space / Yetersiz Alan**
```bash
# Problem / Sorun:
Yetersiz disk alanı! En az 2GB boş alan gerekli.

# Solution / Çözüm:
# Clean package cache / Paket önbelleğini temizleyin
sudo apt clean
sudo apt autoremove

# Remove unnecessary files / Gereksiz dosyaları kaldırın
sudo find /tmp -type f -atime +7 -delete
```

#### **🔒 Package Manager Lock / Paket Yöneticisi Kilidi**
```bash
# Problem / Sorun:
Another package manager is running

# Solution / Çözüm:
# Wait for other processes to finish or kill them
sudo killall apt apt-get dpkg
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
sudo rm /var/lib/dpkg/lock*
```

### 🔄 **Recovery Steps / Kurtarma Adımları:**

#### **1. Restore Backup / Yedekten Geri Yükleme**
```bash
# List available backups / Mevcut yedekleri listeleyin
ls -la /etc/apt/sources.list.backup-*

# Restore sources.list / sources.list'i geri yükleyin
sudo cp /etc/apt/sources.list.backup-YYYYMMDD-HHMMSS /etc/apt/sources.list

# Update package lists / Paket listelerini güncelleyin
sudo apt update
```

#### **2. Fix Broken Packages / Bozuk Paketleri Düzeltin**
```bash
# Fix broken dependencies / Bozuk bağımlılıkları düzeltin
sudo apt --fix-broken install

# Reconfigure packages / Paketleri yeniden yapılandırın
sudo dpkg --configure -a

# Clean package cache / Paket önbelleğini temizleyin
sudo apt clean && sudo apt update
```

#### **3. Emergency Recovery / Acil Durum Kurtarması**
```bash
# Boot into recovery mode and run / Kurtarma modunda açın ve çalıştırın:
sudo apt update --fix-missing
sudo apt full-upgrade --fix-missing
sudo apt autoremove
```

---

## 📊 Advanced Usage / Gelişmiş Kullanım

### 🎛️ **Command Line Options / Komut Satırı Seçenekleri:**

```bash
# View help / Yardımı görüntüleyin
./debian-upgrade.sh --help

# Check version only / Sadece sürümü kontrol edin
./debian-upgrade.sh --version-check

# Dry run (simulation) / Deneme çalıştırması (simülasyon)
./debian-upgrade.sh --dry-run

# Force upgrade without prompts / Sorular olmadan zorla yükselt
./debian-upgrade.sh --force --target=12
```

### 📝 **Custom Configuration / Özel Yapılandırma:**

Create a configuration file / Yapılandırma dosyası oluşturun:
```bash
# Create config file / Yapılandırma dosyası oluşturun
sudo nano /etc/debian-upgrade.conf
```

```bash
# Configuration options / Yapılandırma seçenekleri
BACKUP_DIR="/var/backups/debian-upgrade"
LOG_LEVEL="verbose"
AUTO_REBOOT="false"
MIRROR_URL="http://deb.debian.org/debian"
```

---

## 🤝 Contributing / Katkıda Bulunma

### 🌟 **How to Contribute / Nasıl Katkıda Bulunursunuz:**

1. **🍴 Fork the repository / Depoyu fork edin**
2. **🔀 Create a feature branch / Özellik dalı oluşturun**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **💾 Commit your changes / Değişikliklerinizi commit edin**
   ```bash
   git commit -m 'Add amazing feature'
   ```
4. **📤 Push to the branch / Dalı push edin**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **🔃 Open a Pull Request / Pull Request açın**

### 🐛 **Bug Reports / Hata Raporları:**

**English**: Please include the following information when reporting bugs:
- Debian version
- Error messages
- Log files (`/var/log/debian-upgrade-*.log`)
- Steps to reproduce

**Türkçe**: Hata bildirirken lütfen şu bilgileri ekleyin:
- Debian sürümü
- Hata mesajları
- Log dosyaları (`/var/log/debian-upgrade-*.log`)
- Hatayı tekrar etme adımları

---

## 📋 Testing / Test Etme

### 🧪 **Test Environment / Test Ortamı:**

```bash
# Create test VM / Test VM oluşturun
# Recommended: VirtualBox or VMware with Debian 9/10/11

# Test on different systems / Farklı sistemlerde test edin:
# - Debian 9 (Stretch)
# - Debian 10 (Buster) 
# - Debian 11 (Bullseye)

# Run comprehensive tests / Kapsamlı testler çalıştırın
./run-tests.sh
```

### ✅ **Automated Testing / Otomatik Test:**

```bash
# Unit tests / Birim testler
./tests/unit-tests.sh

# Integration tests / Entegrasyon testleri
./tests/integration-tests.sh

# Performance tests / Performans testleri
./tests/performance-tests.sh
```

---

## 📈 Changelog / Değişiklik Günlüğü

### **v2.0.0** (2024-06-03)
- ✨ Added support for Debian 12 (Bookworm)
- 🛡️ Enhanced security checks
- 📊 Improved progress monitoring
- 🐛 Fixed repository detection issues

### **v1.5.0** (2024-05-15)
- 🎯 Added automatic version detection
- 💾 Implemented backup system
- 📝 Enhanced logging capabilities

### **v1.0.0** (2024-04-01)
- 🚀 Initial release
- 📦 Basic upgrade functionality
- 🔧 Interactive menu system

---

## 🏆 Acknowledgments / Teşekkürler

- **🐧 Debian Project**: For the amazing operating system
- **👥 Community**: For testing and feedback
- **🔧 Contributors**: Everyone who helped improve this script

---

## 📞 Support / Destek

### 💬 **Get Help / Yardım Alın:**

- **🐛 Issues**: [GitHub Issues](https://github.com/yourusername/debian-upgrade-script/issues)
- **💡 Discussions**: [GitHub Discussions](https://github.com/yourusername/debian-upgrade-script/discussions)
- **📧 Email**: your.email@example.com

### 🌐 **Useful Links / Yararlı Bağlantılar:**

- [📚 Debian Documentation](https://www.debian.org/doc/)
- [🔧 Debian Administrator's Handbook](https://debian-handbook.info/)
- [📋 Debian Release Notes](https://www.debian.org/releases/)

---

## 📄 License / Lisans

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Bu proje MIT Lisansı altında lisanslanmıştır - detaylar için [LICENSE](LICENSE) dosyasına bakın.

---

## ⭐ Star History / Yıldız Geçmişi

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/debian-upgrade-script&type=Date)](https://www.star-history.com/#MRsuffixx/debian-update&Date)

---

**🎉 Made with ❤️ by [Your Name](https://github.com/yourusername)**

---

<div align="center">
  <p><b>🌟 If this project helped you, please give it a star! ⭐</b></p>
  <p><b>🌟 Bu proje size yardımcı olduysa, lütfen yıldız verin! ⭐</b></p>
</div>
