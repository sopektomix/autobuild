#!/bin/bash
#--------------------------------------------------------
# 🚀 Universal OpenWrt Builder - Final Professional Version
# 👨‍💻 Author: Sopek Semprit
#--------------------------------------------------------

# === Terminal Colors ===
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

trap "echo -e '\n${RED}🚫 Stopped by user.${NC}'; exit 1" SIGINT

# === Banner Branding ===
show_banner() {
    clear
    message="🚀 Launching Arcadyan Firmware Project by Sopek Semprit..."
    for ((i=0; i<${#message}; i++)); do
        echo -ne "${YELLOW}${message:$i:1}${NC}"
        sleep 0.01
    done
    echo -e "\n"
    for i in $(seq 1 60); do echo -ne "${BLUE}=${NC}"; sleep 0.005; done
    echo -e "\n"

    echo -e "${BLUE}"
    cat << "EOF"
 ____   __  ____  ____  __ _  ____  ____  _  _  ____  ____  __  ____       
/ ___) /  \(  _ \(  __)(  / )/ ___)(  __)( \/ )(  _ \(  _ \(  )(_  _)      
\___ \(  O )) __/ ) _)  )  ( \___ \ ) _) / \/ \ ) __/ )   / )(   )(        
(____/ \__/(__)  (____)(__\_)(____/(____)\_)(_/(__)  (__\_)(__) (__)  

EOF
    echo -e "${NC}"
    for i in $(seq 1 60); do echo -ne "${BLUE}-${NC}"; sleep 0.005; done
    echo -e "\n"

    echo "========================================================="
    echo -e "📦 ${BLUE}Universal OpenWrt/ImmortalWrt/OpenWrt-IPQ/LEDE Builder${NC}"
    echo "========================================================="
    echo -e "👤 ${BLUE}Author   : Sopek Semprit${NC}"
    echo -e "🌐 ${BLUE}GitHub   : https://github.com/sopektomix${NC}"
    echo -e "💬 ${BLUE}Telegram : t.me/sopek21${NC}"
    echo "========================================================="
}

# === Arcadyan AW1000 Disk Expansion ===
expand_aw1000_disk() {
    echo -e "\n${GREEN}=== Arcadyan AW1000 Disk Expansion ===${NC}"
    echo -e "${YELLOW}⚠️ This will resize the root filesystem to 574.33MB${NC}"
    
    # Check if we're in a build directory
    if [ ! -d "target/linux/ipq40xx" ]; then
        echo -e "${RED}❌ Not in an OpenWrt build directory!${NC}"
        return 1
    fi

    # Create backup of original files
    echo -e "${BLUE}📦 Creating backups of original files...${NC}"
    cp target/linux/ipq40xx/image/Makefile target/linux/ipq40xx/image/Makefile.bak
    cp target/linux/ipq40xx/base-files/lib/upgrade/platform.sh target/linux/ipq40xx/base-files/lib/upgrade/platform.sh.bak

    # Modify the Makefile to increase partition size
    echo -e "${BLUE}🔧 Modifying partition layout...${NC}"
    sed -i 's/$(call PartSize,rootfs) = 25600/$(call PartSize,rootfs) = 574330/' target/linux/ipq40xx/image/Makefile

    # Add patch for platform.sh if needed
    if ! grep -q "ARCADYAN_AW1000" target/linux/ipq40xx/base-files/lib/upgrade/platform.sh; then
        echo -e "${BLUE}🔧 Patching platform.sh...${NC}"
        cat >> target/linux/ipq40xx/base-files/lib/upgrade/platform.sh << 'EOF'

arcadyan_aw1000_upgrade_tar_check() {
    local tar_file="$1"
    local board_dir="/tmp/aw1000_upgrade"
    
    mkdir -p "$board_dir"
    tar -C "$board_dir" -xzf "$tar_file" || return 1
    
    [ -f "$board_dir/sysupgrade-aw1000/kernel" ] || return 1
    [ -f "$board_dir/sysupgrade-aw1000/root" ] || return 1
    
    return 0
}

platform_check_image() {
    case "$(board_name)" in
    arcadyan,aw1000)
        arcadyan_aw1000_upgrade_tar_check "$1" || return 1
        ;;
    esac
    
    return 0
}
EOF
    fi

    # Add device-specific package
    echo -e "${BLUE}📦 Adding AW1000-specific packages...${NC}"
    mkdir -p package/arcadyan-aw1000
    cat > package/arcadyan-aw1000/Makefile << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=arcadyan-aw1000
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/arcadyan-aw1000
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Arcadyan AW1000 Utilities
  DEPENDS:=+uboot-envtools +kmod-mtd-rw
endef

define Package/arcadyan-aw1000/description
 Utilities for Arcadyan AW1000 router including disk expansion tools.
endef

define Build/Compile
endef

define Package/arcadyan-aw1000/install
    $(INSTALL_DIR) $(1)/etc/init.d
    $(INSTALL_BIN) ./files/aw1000-disk-expand $(1)/etc/init.d/aw1000-disk-expand
    $(INSTALL_DIR) $(1)/usr/sbin
    $(INSTALL_BIN) ./files/expand-rootfs $(1)/usr/sbin/expand-rootfs
endef

$(eval $(call BuildPackage,arcadyan-aw1000))
EOF

    # Create init script
    mkdir -p package/arcadyan-aw1000/files
    cat > package/arcadyan-aw1000/files/aw1000-disk-expand << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=15

start() {
    if [ ! -f /etc/disk_expanded ]; then
        logger -t aw1000 "Starting root filesystem expansion"
        /usr/sbin/expand-rootfs
        touch /etc/disk_expanded
    fi
}
EOF
    chmod +x package/arcadyan-aw1000/files/aw1000-disk-expand

    # Create expansion script
    cat > package/arcadyan-aw1000/files/expand-rootfs << 'EOF'
#!/bin/sh

logger -t aw1000 "Expanding root filesystem to 574.33MB"

# Resize rootfs partition
echo ", +" | sfdisk -N 3 --no-reread /dev/mtdblock0

# Remount rootfs rw
mount -o remount,rw /

# Resize filesystem
resize2fs /dev/root

logger -t aw1000 "Root filesystem expansion complete"
EOF
    chmod +x package/arcadyan-aw1000/files/expand-rootfs

    # Update config
    echo -e "${BLUE}⚙️ Updating configuration...${NC}"
    cat >> .config << 'EOF'
CONFIG_TARGET_ipq40xx_DEVICE_arcadyan_aw1000=y
CONFIG_PACKAGE_arcadyan-aw1000=y
CONFIG_TARGET_ROOTFS_PARTSIZE=574
EOF

    echo -e "\n${GREEN}✅ Disk expansion configured for Arcadyan AW1000!${NC}"
    echo -e "The root filesystem will now be built with 574.33MB capacity."
    echo -e "The expansion will automatically run on first boot."
}

# === U-Boot Functions for Arcadyan AW1000 ===
uboot_aw1000() {
    echo -e "\n${GREEN}=== Arcadyan AW1000 U-Boot Tools ===${NC}"
    echo "1) Build U-Boot for AW1000"
    echo "2) Flash U-Boot via serial"
    echo "3) Backup current U-Boot"
    echo "4) Restore U-Boot from backup"
    echo "5) Extend disk space to 574.33MB"
    echo "6) Return to main menu"
    read -p "🔹 Choice [1-6]: " uboot_choice

    case "$uboot_choice" in
        1)
            build_aw1000_uboot
            ;;
        2)
            flash_aw1000_uboot
            ;;
        3)
            backup_aw1000_uboot
            ;;
        4)
            restore_aw1000_uboot
            ;;
        5)
            expand_aw1000_disk
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            ;;
    esac
}

build_aw1000_uboot() {
    echo -e "\n${YELLOW}🚧 Building U-Boot for Arcadyan AW1000...${NC}"
    
    # Check if we're in a build directory
    if [ ! -d "package/boot/uboot-envtools" ]; then
        echo -e "${RED}❌ Not in an OpenWrt build directory!${NC}"
        return 1
    fi

    # Add AW1000 specific patches if needed
    if [ ! -f "target/linux/ipq40xx/patches-5.15/999-aw1000-uboot.patch" ]; then
        echo -e "${BLUE}🔧 Adding AW1000 U-Boot patches...${NC}"
        cat > target/linux/ipq40xx/patches-5.15/999-aw1000-uboot.patch << 'EOP'
--- a/package/boot/uboot-envtools/files/ipq40xx
+++ b/package/boot/uboot-envtools/files/ipq40xx
@@ -1,2 +1,3 @@
 /dev/mtd1 0x0 0x10000 0x10000
 /dev/mtd2 0x0 0x10000 0x10000
+/dev/mtd3 0x0 0x10000 0x10000
EOP
    fi

    # Configure for AW1000
    echo -e "${BLUE}⚙️ Configuring for AW1000...${NC}"
    cat >> .config << 'EOC'
CONFIG_TARGET_ipq40xx=y
CONFIG_TARGET_ipq40xx_DEVICE_arcadyan_aw1000=y
CONFIG_PACKAGE_uboot-envtools=y
CONFIG_PACKAGE_kmod-mtd-rw=y
EOC

    # Build U-Boot package
    echo -e "${GREEN}🏗️ Building U-Boot...${NC}"
    make package/boot/uboot-envtools/compile -j$(nproc) || {
        echo -e "${RED}❌ U-Boot build failed!${NC}"
        return 1
    }

    echo -e "\n${GREEN}✅ U-Boot for AW1000 built successfully!${NC}"
    echo -e "Output files can be found in:"
    echo -e "${BLUE}bin/targets/ipq40xx/generic/${NC}"
}

flash_aw1000_uboot() {
    echo -e "\n${YELLOW}⚠️ WARNING: This will flash new U-Boot to your device!${NC}"
    echo -e "${RED}❌ Incorrect flashing can brick your device!${NC}"
    read -p "Are you sure you want to proceed? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        return
    fi

    echo -e "\n${BLUE}🔌 Please connect your AW1000 via serial console${NC}"
    echo -e "1) Set your serial terminal to 115200 baud, 8N1"
    echo -e "2) Power on the device and interrupt U-Boot"
    echo -e "3) Prepare a TFTP server with the U-Boot image"
    read -p "Press enter when ready..."

    # Generate flash commands
    cat << 'EOF'

# On the AW1000 U-Boot console, run these commands:
setenv serverip 192.168.1.100    # Your TFTP server IP
setenv ipaddr 192.168.1.1       # AW1000 IP
tftpboot 0x84000000 uboot.bin   # Your U-Boot image name
sf probe 0
sf erase 0x0 0x100000
sf write 0x84000000 0x0 0x100000
reset

EOF

    echo -e "${GREEN}✅ Flash commands prepared. Copy these to your serial terminal.${NC}"
}

backup_aw1000_uboot() {
    echo -e "\n${BLUE}📥 Creating U-Boot backup...${NC}"
    echo -e "1) Connect via serial and interrupt U-Boot"
    echo -e "2) Prepare a TFTP server to receive the backup"
    read -p "Press enter when ready..."

    cat << 'EOF'

# On the AW1000 U-Boot console, run these commands:
setenv serverip 192.168.1.100    # Your TFTP server IP
setenv ipaddr 192.168.1.1       # AW1000 IP
sf probe 0
sf read 0x84000000 0x0 0x100000
tftpput 0x84000000 0x100000 uboot-backup.bin

EOF

    echo -e "${GREEN}✅ Backup commands prepared. Copy these to your serial terminal.${NC}"
    echo -e "The backup will be saved as 'uboot-backup.bin' on your TFTP server."
}

restore_aw1000_uboot() {
    echo -e "\n${YELLOW}⚠️ WARNING: Restoring U-Boot from backup${NC}"
    read -p "Are you sure you want to proceed? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        return
    fi

    echo -e "\n${BLUE}🔌 Connect via serial and prepare TFTP server with backup file${NC}"
    read -p "Press enter when ready..."

    cat << 'EOF'

# On the AW1000 U-Boot console, run these commands:
setenv serverip 192.168.1.100    # Your TFTP server IP
setenv ipaddr 192.168.1.1       # AW1000 IP
tftpboot 0x84000000 uboot-backup.bin  # Your backup filename
sf probe 0
sf erase 0x0 0x100000
sf write 0x84000000 0x0 0x100000
reset

EOF

    echo -e "${GREEN}✅ Restore commands prepared. Copy these to your serial terminal.${NC}"
}

# === Auto Fix Errors Function ===
auto_fix_errors() {
    echo -e "\n${YELLOW}🛠️  Attempting to auto-fix common build errors...${NC}"
    
    # Fix for common missing dependencies
    echo -e "${BLUE}🔍 Checking and installing build dependencies...${NC}"
    sudo apt-get update
    sudo apt-get install -y build-essential libncurses5-dev gawk git libssl-dev gettext zlib1g-dev swig unzip time rsync python3 python3-setuptools
    
    # Fix for failed downloads
    echo -e "${BLUE}🔄 Cleaning and redownloading failed packages...${NC}"
    make -j1 download
    make -j1 download
    
    # Fix for permission issues
    echo -e "${BLUE}🔒 Fixing permission issues...${NC}"
    sudo chown -R $(whoami) .
    sudo chmod -R u+rw .
    
    # Fix for conflicting object files
    echo -e "${BLUE}🧹 Cleaning conflicting object files...${NC}"
    make clean
    rm -rf tmp
    
    # Fix for outdated feeds
    echo -e "${BLUE}🔄 Updating feeds again...${NC}"
    ./scripts/feeds update -a -f
    ./scripts/feeds install -a -f
    
    # Fix for missing config symbols
    echo -e "${BLUE}⚙️  Regenerating config...${NC}"
    make defconfig
    
    echo -e "${GREEN}✅ Auto-fix attempts completed. Retrying build...${NC}"
}

select_distro() {
    echo -e "${BLUE}Select OpenWrt source:${NC}"
    printf "1) 🏳️  %-15s\n" "openwrt"
    printf "2) 🔧  %-15s\n" "openwrt-ipq"
    printf "3) 💀  %-15s\n" "immortalwrt"
    printf "4) 🔥  %-15s\n" "lede"
    printf "5) 🌟  %-15s\n" "immortalwrt-ipq"
    echo "========================================================="
    read -p "🔹 Choice [1-5]: " distro
    case "$distro" in
        1) git_url="https://github.com/openwrt/openwrt";;
        2) git_url="https://github.com/qosmio/openwrt-ipq";;
        3) git_url="https://github.com/immortalwrt/immortalwrt";;
        4) git_url="https://github.com/coolsnowwolf/lede";;
        5) git_url="https://github.com/Gaojianli/immortalwrt-ipq.git";;
        *) echo -e "${RED}❌ Invalid choice.${NC}"; exit 1;;
    esac
}

checkout_tag() {
    echo -e "${YELLOW}🔍 Fetching git tags list...${NC}"
    mapfile -t tag_list < <(git tag -l | sort -Vr)
    if [[ ${#tag_list[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ No tags found. Using default branch.${NC}"
    else
        for i in "${!tag_list[@]}"; do
            echo "$((i+1))) ${tag_list[$i]}"
        done
        read -p "🔖 Select tag [1-${#tag_list[@]}], Enter to skip: " tag_index
        if [[ -n "$tag_index" ]]; then
            checked_out_tag="${tag_list[$((tag_index-1))]}"
            git checkout "$checked_out_tag"
        fi
    fi
}

add_feeds() {
    echo -e "${YELLOW}🔍 Adjusting luci feed based on tag...${NC}"

    luci_branch="master"
    if [[ "$checked_out_tag" =~ ^v([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        luci_branch="openwrt-${major}.${minor}"
    fi

    echo -e "${GREEN}✅ Luci feed will use branch: ${luci_branch}${NC}"

    # Rewrite feed.conf.default
    echo "src-git luci https://github.com/openwrt/luci;$luci_branch" > feeds.conf.default

    echo -e "${BLUE}Select additional feeds:${NC}"
    printf "1) ❌  %-25s\n" "No additional feeds"
    printf "2) 🧪  %-25s\n" "Custom Feed (sopektomix)"
    printf "3) 🐘  %-25s\n" "PHP7 Feed (Legacy)"
    printf "4) 🌐  %-25s\n" "Custom + PHP7"
    echo "========================================================="
    read -p "🔹 Choose [1-4]: " feed_choice

    case "$feed_choice" in
        2)
            echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
            ;;
        3)
            echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default
            ;;
        4)
            echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
            echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default
            ;;
        1) ;; # No additional feeds
        *) echo -e "${RED}❌ Invalid choice.${NC}"; exit 1 ;;
    esac

    echo -e "${GREEN}🔄 Updating feeds...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a
}

use_preset_menu() {
    echo -e "${BLUE}Use preset config?${NC}"
    echo "1) ✅ Yes (recommended)"
    echo "2) 🏗️ No (use menuconfig)"
    read -p "🔹 Choice [1-2]: " preset_answer

    if [[ "$preset_answer" == "1" ]]; then
        if [[ ! -d "../preset" ]]; then
            echo -e "${YELLOW}📦 Cloning preset config...${NC}"
            if ! git clone "https://github.com/sopektomix/preset.git" "../preset"; then
                echo -e "${RED}❌ Failed to clone preset. Proceeding with manual config.${NC}"
                make menuconfig
                return
            fi
        fi

        echo -e "${BLUE}📂 Available presets:${NC}"
        mapfile -t folders < <(find ../preset -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        
        if [[ ${#folders[@]} -eq 0 ]]; then
            echo -e "${RED}❌ No preset folders found. Proceeding with manual config.${NC}"
            make menuconfig
            return
        fi

        for i in "${!folders[@]}"; do
            echo "$((i+1))) ${folders[$i]}"
        done

        read -p "🔹 Select preset folder [1-${#folders[@]}]: " preset_choice
        selected_folder="../preset/${folders[$((preset_choice-1))]}"
        cp -rf "$selected_folder"/* ./
        [[ -f "$selected_folder/config-nss" ]] && cp "$selected_folder/config-nss" .config
    else
        [[ ! -f .config ]] && make menuconfig
    fi
}

build_action_menu() {
    echo -e "\n📋 ${BLUE}Build Menu:${NC}"
    printf "1) 🔄  %-30s\n" "Update feeds only"
    printf "2) 🧪  %-30s\n" "Update feeds + menuconfig"
    printf "3) 🛠️  %-30s\n" "Run menuconfig only"
    printf "4) 🏗️  %-30s\n" "Start build process"
    printf "5) 🔙  %-30s\n" "Back to previous menu"
    printf "6) ❌  %-30s\n" "Exit script"
    echo "========================================================="
    read -p "🔹 Choice [1-6]: " choice
    case "$choice" in
        1) ./scripts/feeds update -a && ./scripts/feeds install -a ;;
        2) ./scripts/feeds update -a && ./scripts/feeds install -a; make menuconfig ;;
        3) make menuconfig ;;
        4) return 0 ;;
        5) cd ..; return 1 ;;
        6) echo -e "${GREEN}🙋 Exiting.${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠️ Invalid input.${NC}" ;;
    esac
    return 1
}

start_build() {
    echo -e "${GREEN}🚀 Starting build with 20 threads...${NC}"
    echo -e "${YELLOW}📝 Compile logs will be saved to:${NC}"
    echo -e "  - ${BLUE}build.log${NC} (standard output)"
    echo -e "  - ${BLUE}build-error.log${NC} (errors only)"
    echo -e "  - ${BLUE}build-full.log${NC} (verbose output)"
    
    start_time=$(date +%s)
    
    # First attempt with standard logging
    echo -e "\n${BLUE}=== Initial Build Attempt (standard logging) ===${NC}"
    make -j20 2>&1 | tee build.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo -e "${RED}⚠️ Build failed, attempting auto-fix...${NC}"
        auto_fix_errors
        
        # Second attempt with verbose logging
        echo -e "\n${BLUE}=== Retry Build Attempt (verbose logging) ===${NC}"
        make -j20 V=s 2>&1 | tee build-full.log
        
        # Extract errors to separate file
        grep -iE 'error:|fail|warning:' build-full.log > build-error.log
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo -e "${RED}❌ Build failed after retry. Check logs:${NC}"
            echo -e "  - ${RED}build-error.log${NC} (errors extracted)"
            echo -e "  - ${RED}build-full.log${NC} (full verbose output)"
        else
            echo -e "${GREEN}✅ Build successful after retry!${NC}"
        fi
    else
        echo -e "${GREEN}✅ Build successful on first attempt!${NC}"
    fi
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    echo -e "${BLUE}⏱️ Build completed in $((elapsed / 60)) minutes $((elapsed % 60)) seconds.${NC}"
    command -v notify-send &>/dev/null && notify-send "OpenWrt Build" "✅ Build completed in folder: $(pwd)"
}

fresh_build() {
    echo -e "\n📁 Select new build folder:"
    printf "1) %-20s 4) %s\n" "openwrt"       "lede (coolsnowwolf)"
    printf "2) %-20s 5) %s\n" "immortalwrt"   "immortalwrt-ipq (Gaojianli)"
    printf "3) %-20s\n" "openwrt-ipq (qosmio)"

    while true; do
        read -p "🔹 Choice [1-5]: " choice
        case "$choice" in
            1) folder_name="openwrt";       git_url="https://github.com/openwrt/openwrt";;
            2) folder_name="immortalwrt";   git_url="https://github.com/immortalwrt/immortalwrt";;
            3) folder_name="openwrt-ipq";   git_url="https://github.com/qosmio/openwrt-ipq";;
            4) folder_name="lede";          git_url="https://github.com/coolsnowwolf/lede.git";;
            5) folder_name="immortalwrt-ipq"; git_url="https://github.com/Gaojianli/immortalwrt-ipq.git";;
            *) echo -e "${RED}❌ Invalid choice.${NC}"; continue;;
        esac
        break
    done

    echo -e "\n📂 Selected folder : ${YELLOW}$folder_name${NC}"
    mkdir -p "$folder_name" && cd "$folder_name" || { echo -e "${RED}❌ Failed to enter folder.${NC}"; exit 1; }

    echo -e "🔗 Cloning from: ${GREEN}$git_url${NC}"
    git clone "$git_url" . || { echo -e "${RED}❌ Failed to clone repo.${NC}"; exit 1; }

    echo -e "${GREEN}🔄 Running initial feed update & install...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a

    checkout_tag
    add_feeds
    use_preset_menu

    if ! grep -q "^CONFIG_TARGET" .config 2>/dev/null; then
        echo -e "${RED}❌ Target board not configured. Running menuconfig first.${NC}"
        make menuconfig
    fi

    start_build
}

rebuild_mode() {
    while true; do
        show_banner
        echo -e "📂 ${BLUE}Select existing build folder:${NC}"
        mapfile -t folders < <(find . -maxdepth 1 -type d ! -name ".")
        for i in "${!folders[@]}"; do
            echo "$((i+1))) ${folders[$i]##*/}"
        done
        echo "0) Exit"
        read -p "🔹 Choice [0-${#folders[@]}]: " choice
        if [[ "$choice" == 0 ]]; then
            echo -e "${GREEN}🙋 Exiting.${NC}"; exit 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -le "${#folders[@]}" ]]; then
            folder="${folders[$((choice-1))]}"
            cd "$folder" || continue
            while ! build_action_menu; do :; done
            start_build
            break
        else
            echo -e "${RED}⚠️ Invalid choice.${NC}"
        fi
    done
}

main_menu() {
    show_banner
    echo "1️⃣ Fresh build (new)"
    echo "2️⃣ Rebuild from existing folder"
    echo "3️⃣ Arcadyan AW1000 Tools"
    echo "4️⃣ Exit"
    echo "========================================================="
    read -p "🔹 Select option [1-4]: " main_choice
    case "$main_choice" in
        1) fresh_build ;;
        2) rebuild_mode ;;
        3) uboot_aw1000 ;;
        4) echo -e "${GREEN}🙋 Exiting.${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠️ Invalid choice.${NC}"; exit 1 ;;
    esac
}

# === Start ===
main_menu
