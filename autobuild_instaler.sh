#!/bin/bash
#--------------------------------------------------------
# 🚀 Universal OpenWrt Builder - Enhanced Professional Version
# 👨‍💻 Author: Sopek Semprit
#--------------------------------------------------------

# === Configuration ===
CCACHE_ENABLED=true
MIN_DISK_SPACE=10 # GB
MAX_RETRIES=3

# === Terminal Colors ===
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# === Error Handling ===
trap "echo -e '\n${RED}🚫 Stopped by user.${NC}'; exit 1" SIGINT

# === System Checks ===
check_system() {
    local errors=0
    
    # Check disk space
    local avail_space=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$avail_space" -lt "$MIN_DISK_SPACE" ]; then
        echo -e "${RED}❌ Insufficient disk space (min ${MIN_DISK_SPACE}GB required).${NC}"
        ((errors++))
    fi

    # Check build tools
    local required_tools=(git make gcc g++ python3)
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${RED}❌ Missing required tool: $tool${NC}"
            ((errors++))
        fi
    done

    [ $errors -gt 0 ] && exit 1
}

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
                             
© Project by SopekSemprit
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

# === Helper Functions ===
validate_number() {
    local input=$1
    local min=$2
    local max=$3
    [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge "$min" ] && [ "$input" -le "$max" ]
}

git_retry() {
    local retries=0
    until "$@"; do
        ((retries++))
        if [ "$retries" -ge "$MAX_RETRIES" ]; then
            echo -e "${RED}❌ Failed after $MAX_RETRIES attempts${NC}"
            return 1
        fi
        echo -e "${YELLOW}⚠️ Retrying ($retries/$MAX_RETRIES)...${NC}"
        sleep 3
    done
}

apply_lede_patch() {
    echo -e "${YELLOW}🔧 Applying LEDE-specific patch...${NC}"
    if [ -f "target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch" ]; then
        mkdir -p target/linux/qualcommax/patches-6.1/
        if cp -v target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch \
               target/linux/qualcommax/patches-6.1/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch; then
            echo -e "${GREEN}✅ Patch copied successfully${NC}"
        else
            echo -e "${RED}❌ Failed to copy patch${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️ Original patch file not found, skipping${NC}"
        return 1
    fi
}

# === Main Functions ===
select_distro() {
    while true; do
        echo -e "${BLUE}Select OpenWrt source:${NC}"
        printf "1) 🏳️  %-15s\n" "openwrt"
        printf "2) 🔧  %-15s\n" "openwrt-ipq"
        printf "3) 💀  %-15s\n" "immortalwrt"
        printf "4) 🔥  %-15s\n" "LEDE"
        printf "5) 🚀  %-15s\n" "immortalwrt-ipq"
        echo "========================================================="
        read -p "🔹 Choice [1-5]: " distro
        
        case "$distro" in
            1) git_url="https://github.com/openwrt/openwrt"; break;;
            2) git_url="https://github.com/qosmio/openwrt-ipq"; break;;
            3) git_url="https://github.com/immortalwrt/immortalwrt"; break;;
            4) git_url="https://github.com/coolsnowwolf/lede.git"; break;;
            5) git_url="https://github.com/Gaojianli/immortalwrt-ipq.git"; break;;
            *) echo -e "${RED}❌ Invalid choice. Please try again.${NC}";;
        esac
    done
}

checkout_tag() {
    echo -e "${YELLOW}🔍 Fetching git tags...${NC}"
    mapfile -t tag_list < <(git tag -l | sort -Vr)
    if [[ ${#tag_list[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ No tags found. Using default branch.${NC}"
    else
        for i in "${!tag_list[@]}"; do
            echo "$((i+1))) ${tag_list[$i]}"
        done
        while true; do
            read -p "🔖 Select tag [1-${#tag_list[@]}], Enter to skip: " tag_index
            [[ -z "$tag_index" ]] && break
            if validate_number "$tag_index" 1 "${#tag_list[@]}"; then
                git checkout "${tag_list[$((tag_index-1))]}" && break
                echo -e "${RED}❌ Failed to checkout tag. Try again.${NC}"
            else
                echo -e "${RED}❌ Invalid selection. Try again.${NC}"
            fi
        done
    fi
}

add_feeds() {
    if ! grep -q "src-git luci" feeds.conf.default 2>/dev/null; then
        echo "src-git luci https://github.com/openwrt/luci" >> feeds.conf.default
    fi
    
    # Add additional feeds based on source
    case "$git_url" in
        *lede*)
            echo "src-git packages https://github.com/coolsnowwolf/packages" >> feeds.conf.default
            echo "src-git luci https://github.com/coolsnowwolf/luci" >> feeds.conf.default
            echo "src-git routing https://github.com/coolsnowwolf/routing" >> feeds.conf.default
            apply_lede_patch
            ;;
        *immortalwrt-ipq*)
            echo "src-git nss https://github.com/Gaojianli/nss-packages" >> feeds.conf.default
            ;;
    esac

    echo -e "${BLUE}Select additional feeds:${NC}"
    printf "1) ❌  %-25s\n" "No additional feeds"
    printf "2) 🛠️  %-25s\n" "Custom Feed (BootLoopLover)"
    printf "3) 🐘  %-25s\n" "PHP7 Feed (Legacy)"
    printf "4) 🌐  %-25s\n" "Custom + PHP7"
    echo "========================================================="
    
    while true; do
        read -p "🔹 Choice [1-4]: " feed_choice
        case "$feed_choice" in
            1) break;;
            2) 
                echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
                break;;
            3) 
                echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default
                break;;
            4)
                echo "src-git custom https://github.com/BootLoopLover/custom-package" >> feeds.conf.default
                echo "src-git php7 https://github.com/BootLoopLover/openwrt-php7-package" >> feeds.conf.default
                break;;
            *) echo -e "${RED}❌ Invalid choice. Try again.${NC}";;
        esac
    done
    
    echo -e "${GREEN}🔄 Updating feeds...${NC}"
    if ! ./scripts/feeds update -a; then
        echo -e "${RED}❌ Failed to update feeds${NC}"
        exit 1
    fi
    if ! ./scripts/feeds install -a; then
        echo -e "${RED}❌ Failed to install feeds${NC}"
        exit 1
    fi
}

use_preset_menu() {
    echo -e "${BLUE}Use preset config?${NC}"
    echo "1) ✅ Yes (recommended)"
    echo "2) ❌ No (manual config)"
    read -p "🔹 Choice [1-2]: " preset_answer

    if [[ "$preset_answer" == "1" ]]; then
        [[ ! -d "../preset" ]] && git_retry git clone "https://github.com/BootLoopLover/preset.git" "../preset" || {
            echo -e "${RED}❌ Failed to clone preset.${NC}"; exit 1;
        }
        echo -e "${BLUE}Available presets:${NC}"
        mapfile -t folders < <(find ../preset -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        for i in "${!folders[@]}"; do
            echo "$((i+1))) ${folders[$i]}"
        done
        while true; do
            read -p "🔹 Select preset folder [1-${#folders[@]}]: " preset_choice
            if validate_number "$preset_choice" 1 "${#folders[@]}"; then
                selected_folder="../preset/${folders[$((preset_choice-1))]}"
                cp -rf "$selected_folder"/* ./
                [[ -f "$selected_folder/config-nss" ]] && cp "$selected_folder/config-nss" .config
                break
            else
                echo -e "${RED}❌ Invalid selection. Try again.${NC}"
            fi
        done
    else
        [[ ! -f .config ]] && make menuconfig
    fi
}

build_action_menu() {
    while true; do
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
            1) 
                ./scripts/feeds update -a && ./scripts/feeds install -a
                break;;
            2) 
                ./scripts/feeds update -a && ./scripts/feeds install -a
                make menuconfig
                break;;
            3) 
                make menuconfig
                break;;
            4) 
                return 0;;
            5) 
                cd ..
                return 1;;
            6) 
                echo -e "${GREEN}🙋 Exiting.${NC}"
                exit 0;;
            *) 
                echo -e "${RED}⚠️ Invalid input.${NC}";;
        esac
    done
    return 1
}

start_build() {
    echo -e "${GREEN}🚀 Starting build with 10 threads...${NC}"
    start_time=$(date +%s)
    
    # First attempt with parallel build
    if make -j10 > build.log 2>&1; then
        echo -e "${GREEN}✅ Build successful!${NC}"
    else
        echo -e "${RED}⚠️ Build failed, retrying with verbose output...${NC}"
        # Second attempt with verbose output
        if ! make -j10 V=s 2>&1 | tee build-error.log; then
            echo -e "${RED}❌ Build failed even with verbose output.${NC}"
            echo -e "${YELLOW}⚠️ Check build-error.log for details.${NC}"
            exit 1
        fi
    fi
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    echo -e "${BLUE}⏱️ Build completed in $((elapsed / 60)) minutes $((elapsed % 60)) seconds.${NC}"
    command -v notify-send &>/dev/null && notify-send "OpenWrt Build" "✅ Build completed in folder: $(pwd)"
}

fresh_build() {
    echo -e "\n📁 Select new build folder:"
    printf "1) %-20s 4) %s\n" "openwrt"       "LEDE"
    printf "2) %-20s 5) %s\n" "immortalwrt"   "immortalwrt-ipq"
    printf "3) %-20s 6) %s\n" "openwrt-ipq"   "Custom (enter manually)"

    while true; do
        read -p "🔹 Choice [1-6]: " choice
        case "$choice" in
            1) folder_name="openwrt";       git_url="https://github.com/openwrt/openwrt"; break;;
            2) folder_name="immortalwrt";   git_url="https://github.com/immortalwrt/immortalwrt"; break;;
            3) folder_name="openwrt-ipq";   git_url="https://github.com/qosmio/openwrt-ipq"; break;;
            4) folder_name="lede";          git_url="https://github.com/coolsnowwolf/lede.git"; break;;
            5) folder_name="immortalwrt-ipq"; git_url="https://github.com/Gaojianli/immortalwrt-ipq.git"; break;;
            6) 
                read -p "Custom folder name: " custom_name
                folder_name="${custom_name:-custom_build}"
                select_distro
                break;;
            *) echo -e "${RED}❌ Invalid choice.${NC}";;
        esac
    done

    echo -e "\n📂 Folder dipilih : ${YELLOW}$folder_name${NC}"
    mkdir -p "$folder_name" && cd "$folder_name" || { echo -e "${RED}❌ Gagal masuk folder.${NC}"; exit 1; }

    echo -e "🔗 Clone dari: ${GREEN}$git_url${NC}"
    git clone "$git_url" . || { echo -e "${RED}❌ Gagal clone repo.${NC}"; exit 1; }

    echo -e "${GREEN}🔄 Menjalankan update & install feeds awal...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a

    checkout_tag
    add_feeds
    use_preset_menu

    if ! grep -q "^CONFIG_TARGET" .config 2>/dev/null; then
        echo -e "${RED}❌ Target board not configured. Run menuconfig first.${NC}"
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
        echo "0) ❌ Exit"
        
        while true; do
            read -p "🔹 Choice [0-${#folders[@]}]: " choice
            if [[ "$choice" == 0 ]]; then
                echo -e "${GREEN}🙋 Exiting.${NC}"
                exit 0
            elif validate_number "$choice" 1 "${#folders[@]}"; then
                folder="${folders[$((choice-1))]}"
                cd "$folder" || continue
                while ! build_action_menu; do :; done
                start_build
                break 2
            else
                echo -e "${RED}⚠️ Invalid choice.${NC}"
            fi
        done
    done
}

main_menu() {
    check_system
    show_banner
    echo "1️⃣ Fresh build (new)"
    echo "2️⃣ Rebuild from existing folder"
    echo "3️⃣ Exit"
    echo "========================================================="
    
    while true; do
        read -p "🔹 Select option [1-3]: " main_choice
        case "$main_choice" in
            1) fresh_build; break;;
            2) rebuild_mode; break;;
            3) 
                echo -e "${GREEN}🙋 Exiting.${NC}"
                exit 0;;
            *) 
                echo -e "${RED}⚠️ Invalid choice.${NC}";;
        esac
    done
}

# === Start ===
main_menu
