#!/bin/bash
#--------------------------------------------------------
# 🚀 Universal OpenWrt Builder with Arcadyan AW1000 Support
# 👨‍💻 Author: Sopek Semprit
#--------------------------------------------------------

# ... [Previous code remains the same until prepare_aw1000_uboot function] ...

prepare_aw1000_uboot() {
    echo -e "\n${GREEN}=== Preparing U-Boot for Arcadyan AW1000 ===${NC}"
    
    # Check if we're in the correct directory
    if [[ ! -d "package/boot/uboot-arcadyan" ]]; then
        echo -e "${YELLOW}➡️ Adding Arcadyan U-Boot package...${NC}"
        mkdir -p package/boot/uboot-arcadyan
        cat > package/boot/uboot-arcadyan/Makefile << 'EOF'
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2023 Sopek Semprit

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-arcadyan-aw1000
PKG_VERSION:=2023.10
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/u-boot/u-boot.git
PKG_SOURCE_VERSION:=v$(PKG_VERSION)
PKG_MIRROR_HASH:=skip

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/uboot-arcadyan-aw1000
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for Arcadyan AW1000
  DEPENDS:=@TARGET_ar71xx
endef

define Build/Configure
	$(MAKE) -C $(PKG_BUILD_DIR) \
		$(PKG_NAME)_defconfig
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CROSS_COMPILE=$(TARGET_CROSS)
endef

define Package/uboot-arcadyan-aw1000/install
	$(INSTALL_DIR) $(BIN_DIR)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/u-boot.bin $(BIN_DIR)/uboot-arcadyan-aw1000.bin
endef

$(eval $(call BuildPackage,uboot-arcadyan-aw1000))
EOF

        echo -e "${GREEN}✅ Added Arcadyan AW1000 U-Boot package${NC}"
    else
        echo -e "${BLUE}ℹ️ Arcadyan U-Boot package already exists${NC}"
    fi

    # Add extended storage support patches
    if [[ ! -f "target/linux/ar71xx/patches-4.14/911-uboot-aw1000-extstorage.patch" ]]; then
        echo -e "${YELLOW}➡️ Adding AW1000 extended storage patch...${NC}"
        cat > target/linux/ar71xx/patches-4.14/911-uboot-aw1000-extstorage.patch << 'EOF'
--- a/arch/mips/ath79/mach-aw1000.c
+++ b/arch/mips/ath79/mach-aw1000.c
@@ -44,6 +44,12 @@
 	ath79_init_mac(ath79_eth0_data.mac_addr, ath79_mac_base, 0);
 	ath79_register_eth(0);
+
+	/* Extended storage support */
+	ath79_register_m25p80(NULL);
+	ath79_register_nand();
+	ath79_register_usb();
 }
 
 MIPS_MACHINE(ATH79_MACH_AW1000, "AW1000", "Arcadyan AW1000", aw1000_setup);
EOF
        echo -e "${GREEN}✅ Added extended storage support patch${NC}"
    fi
}

configure_aw1000() {
    echo -e "\n${GREEN}=== Configuring for Arcadyan AW1000 ===${NC}"
    
    # Select target profile
    sed -i 's/CONFIG_TARGET_ar71xx_generic_DEVICE_.*/CONFIG_TARGET_ar71xx_generic_DEVICE_arcadyan_aw1000=y/' .config
    echo -e "${BLUE}ℹ️ Selected Arcadyan AW1000 as target device${NC}"
    
    # Enable U-Boot
    echo "CONFIG_PACKAGE_uboot-arcadyan-aw1000=y" >> .config
    echo -e "${BLUE}ℹ️ Enabled Arcadyan AW1000 U-Boot${NC}"
    
    # Extended storage configuration
    echo "CONFIG_TARGET_ROOTFS_EXT4FS=y" >> .config
    echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y" >> .config
    echo "CONFIG_TARGET_IMAGES_GZIP=y" >> .config
    echo "CONFIG_PACKAGE_block-mount=y" >> .config
    echo "CONFIG_PACKAGE_kmod-fs-ext4=y" >> .config
    echo "CONFIG_PACKAGE_kmod-usb-storage=y" >> .config
    echo "CONFIG_PACKAGE_kmod-usb-storage-extras=y" >> .config
    echo "CONFIG_PACKAGE_kmod-nls-cp437=y" >> .config
    echo "CONFIG_PACKAGE_kmod-nls-iso8859-1=y" >> .config
    echo "CONFIG_PACKAGE_kmod-nls-utf8=y" >> .config
    echo "CONFIG_PACKAGE_badblocks=y" >> .config
    echo "CONFIG_PACKAGE_e2fsprogs=y" >> .config
    echo "CONFIG_PACKAGE_fdisk=y" >> .config
    echo "CONFIG_PACKAGE_lsblk=y" >> .config
    echo "CONFIG_PACKAGE_resize2fs=y" >> .config
    echo "CONFIG_PACKAGE_usbutils=y" >> .config
    
    echo -e "${GREEN}✅ Added extended storage support configurations${NC}"
}

add_extended_storage_script() {
    echo -e "\n${YELLOW}➡️ Adding extended storage initialization script...${NC}"
    
    mkdir -p files/etc/init.d
    cat > files/etc/init.d/extstorage << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

EXT_MOUNT="/mnt/extstorage"
EXT_DEVICE="/dev/sda1"

start() {
    if [ ! -b "$EXT_DEVICE" ]; then
        logger "Extended storage: Device $EXT_DEVICE not found"
        return 1
    fi

    mkdir -p "$EXT_MOUNT"
    
    if ! mountpoint -q "$EXT_MOUNT"; then
        fsck.ext4 -p "$EXT_DEVICE"
        mount "$EXT_DEVICE" "$EXT_MOUNT"
        
        if [ $? -eq 0 ]; then
            logger "Extended storage: Successfully mounted $EXT_DEVICE to $EXT_MOUNT"
            
            # Move overlay to extended storage
            if [ ! -d "$EXT_MOUNT/overlay" ]; then
                mkdir -p "$EXT_MOUNT/overlay"
                chown root:root "$EXT_MOUNT/overlay"
                chmod 0755 "$EXT_MOUNT/overlay"
            fi
            
            if ! mountpoint -q "/overlay"; then
                mount --bind "$EXT_MOUNT/overlay" /overlay
                logger "Extended storage: Overlay moved to extended storage"
            fi
        else
            logger "Extended storage: Failed to mount $EXT_DEVICE"
        fi
    fi
}

stop() {
    if mountpoint -q "$EXT_MOUNT"; then
        umount "$EXT_MOUNT"
        logger "Extended storage: Unmounted $EXT_MOUNT"
    fi
}
EOF

    chmod +x files/etc/init.d/extstorage
    
    # Add to rc.local
    mkdir -p files/etc/rc.local.d
    echo "/etc/init.d/extstorage start" > files/etc/rc.local.d/extstorage
    
    echo -e "${GREEN}✅ Added extended storage initialization script${NC}"
}

# ... [Previous functions remain the same until build_action_menu] ...

build_action_menu() {
    echo -e "\n📋 ${BLUE}Build Menu:${NC}"
    printf "1) 🔄  %-30s\n" "Update feeds only"
    printf "2) 🧪  %-30s\n" "Update feeds + menuconfig"
    printf "3) 🛠️  %-30s\n" "Run menuconfig only"
    printf "4) 🏗️  %-30s\n" "Start build process"
    printf "5) 🅰️  %-30s\n" "Arcadyan AW1000 Setup"
    printf "6) 💾  %-30s\n" "Add Extended Storage"
    printf "7) 🔙  %-30s\n" "Back to previous menu"
    printf "8) ❌  %-30s\n" "Exit script"
    echo "========================================================="
    read -p "🔹 Choice [1-8]: " choice
    case "$choice" in
        1) ./scripts/feeds update -a && ./scripts/feeds install -a ;;
        2) ./scripts/feeds update -a && ./scripts/feeds install -a; make menuconfig ;;
        3) make menuconfig ;;
        4) return 0 ;;
        5) prepare_aw1000_uboot; configure_aw1000 ;;
        6) add_extended_storage_script ;;
        7) cd ..; return 1 ;;
        8) echo -e "${GREEN}🙋 Exiting.${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠️ Invalid input.${NC}" ;;
    esac
    return 1
}

# ... [Remaining functions stay the same] ...

main_menu() {
    show_banner
    echo "1️⃣ Fresh build (new)"
    echo "2️⃣ Rebuild from existing folder"
    echo "3️⃣ Arcadyan AW1000 Setup"
    echo "4️⃣ Add Extended Storage"
    echo "5️⃣ Exit"
    echo "========================================================="
    read -p "🔹 Select option [1-5]: " main_choice
    case "$main_choice" in
        1) fresh_build ;;
        2) rebuild_mode ;;
        3) prepare_aw1000_uboot; configure_aw1000 ;;
        4) add_extended_storage_script ;;
        5) echo -e "${GREEN}🙋 Exiting.${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠️ Invalid choice.${NC}"; exit 1 ;;
    esac
}

# === Start ===
main_menu
