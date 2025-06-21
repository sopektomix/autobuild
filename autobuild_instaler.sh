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
    echo -e "💬 ${BLUE}Telegram : t.me/PakaloloWaras0${NC}"
    echo "========================================================="
}

# === LEDE Patch Function ===
apply_lede_patch() {
    echo -e "${YELLOW}🔧 Applying LEDE-specific patch...${NC}"
    if [ -d "target/linux/qualcommax" ]; then
        if [ -f "target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch" ]; then
            mkdir -p target/linux/qualcommax/patches-6.1/
            if cp -v target/linux/qualcommax/patches-6.6/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch \
                   target/linux/qualcommax/patches-6.1/0400-mtd-rawnand-add-support-for-TH58NYG3S0HBAI4.patch; then
                echo -e "${GREEN}✅ Patch copied successfully${NC}"
            else
                echo -e "${RED}❌ Failed to copy patch${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ Patch file not found, skipping${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Folder target/linux/qualcommax not found, skipping patch${NC}"
    fi
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

# === Preset Config Menu ===
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

# === Build Menu & Execution ===
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
    start_time=$(date +%s)
    if make -j20 > build.log 2>&1; then
        echo -e "${GREEN}✅ Build successful!${NC}"
    else
        echo -e "${RED}⚠️ Build failed, retrying with verbose output...${NC}"
        make -j20 V=s | tee build-error.log
    fi
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    echo -e "${BLUE}⏱️ Build completed in $((elapsed / 60)) minutes $((elapsed % 60)) seconds.${NC}"
    command -v notify-send &>/dev/null && notify-send "OpenWrt Build" "✅ Build completed in folder: $(pwd)"
}

# === Fresh Build ===
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

    [[ "$git_url" == *"coolsnowwolf/lede"* ]] && apply_lede_patch

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
    echo "3️⃣ Exit"
    echo "========================================================="
    read -p "🔹 Select option [1-3]: " main_choice
    case "$main_choice" in
        1) fresh_build ;;
        2) rebuild_mode ;;
        3) echo -e "${GREEN}🙋 Exiting.${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠️ Invalid choice.${NC}"; exit 1 ;;
    esac
}

# === Start ===
main_menu
