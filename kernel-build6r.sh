#!/bin/bash
# Avraham Freeman kernel menu

# Define color codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color
UNDER_LINE=$(echo -e "\e[4m")    # Text Under LINE

# Function to print message
pnt_msg() {
  local color=$1
  shift
  echo -e "${color}${BOLD}$@${NC}"
}

# Variables to export
K_DIR="$(pwd)"
menu_version="v3.8"
TOOLCHAIN=${K_DIR}/toolchains
TOOLS=${K_DIR}/toys
AIK=${TOOLS}/AIK-LINUX
STOCK_BOOT=${K_DIR}/stock-boot/*
DTBTOOL=${TOOLS}/dtb/mkdtboimg.py
DTB_DIR=${K_DIR}/arch/arm64/boot/dts/*/*/
OUT=$K_DIR/output
export K_DIR TOOLCHAIN TOOLS AIK STOCK_BOOT DTBTOOL DTB_DIR OUT
export KERNEL_MAKE_ENV="LOCALVERSION=-$USER"
export PLATFORM_VERSION= # please fill in
export ANDROID_MAJOR_VERSION= # please fill in
export VARIANT=omega-kernel # type in name of your kernel or device

# Make directories
mkdir -p $TOOLS
mkdir -p $OUT
mkdir -p stock-boot
# Function to find $user
get_user() {
  echo "Hello and welcome to the Flame Kernel build6r"
  echo "What is your name? (to be used in anykernel.zip and kernel variant)"
  read -p "Please enter your name: " name
  USER=$name
  export USER
main
}

# Press enter
pause() {
  read -p "${RED}Press ${BLUE}[Enter]${STD} key to ${1}..." fackEnterKey
}

# Function to clone GCC toolchain
clone_gcc() {
  echo -e "${RED}Cloning GCC toolchain...${NC}"
  git clone --branch android-9.0.0_r59 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 ${TOOLCHAIN}/aarch64-linux-android-4.9
  export PATH=$(pwd)/toolchains/aarch64-linux-android-4.9/bin:$PATH
  export CROSS_COMPILE=$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-
  export GCC_AR=$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-ar
  export GCC_NM=$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-nm
  export GCC_OBJCOPY=$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-objcopy
  export GCC_OBJDUMP=$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-objdump
  export GCC_STRIP=$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-strip
  echo "GCC toolchain cloned and PATH updated."
 main
}

# Function to clone Clang toolchain
clone_clang() {
  echo -e "${RED}Cloning Clang toolchain...${NC}"
  git clone --depth=1 https://github.com/kdrag0n/proton-clang.git ${TOOLCHAIN}/clang
  export PATH=${TOOLCHAIN}/clang/bin:$PATH
  export ARCH=arm64
  export CROSS_COMPILE=${TOOLCHAIN}/clang/bin/aarch64-linux-gnu-
  export CROSS_COMPILE_ARM32=${TOOLCHAIN}/clang/bin/arm-linux-gnueabi-
  export AR=llvm-ar
  export NM=llvm-nm
  export OBJCOPY=llvm-objcopy
  export OBJDUMP=llvm-objdump
  export STRIP=llvm-strip
  echo "Clang toolchain cloned and PATH updated."
main
}

# Function to read user input and execute corresponding toolchain clone
choose_toolchain() {
  echo -e "${YELLOW}Please choose to build with clang or gcc (based on your kernel)${NC}"
  echo -e "${RED}Enter toolchain [ 1 - 2 ]${NC}"
  read -p "1) GCC Toolchain
2) Clang Toolchain
Enter choice: " toolchain
  case $toolchain in
    1|g|G) clone_gcc ;;
    2|c|C) clone_clang ;;
    3|x|X) exit 0 ;;
    *) echo -e "${RED}Invalid option, returning to toolchain selection${NC}"
       choose_toolchain ;;
  esac
  main
}

# Function to get defconfig
get_defconfig() {
  # List available defconfig files
  echo "${RED}${BOLD}Available defconfig files:${NC}"
  ls ${KERNEL_DIR}/arch/arm64/configs/

  # Prompt user to choose a defconfig file
  echo "Please type in the name of the defconfig you would like to use:"
  read -p "Enter defconfig: " CHOICE

  # Set the chosen defconfig to DEFCONFIG variable
  DEFCONFIG=$CHOICE
  export DEFCONFIG
  echo "Chosen defconfig $DEFCONFIG"
  main
}

# Function to clean
clean() {
  echo "${GREEN}***** Cleaning in Progress *****${NC}"
  make ${KERNEL_MAKE_ENV} CROSS_COMPILE=${CROSS_COMPILE} clean 
  make ${KERNEL_MAKE_ENV} CROSS_COMPILE=${CROSS_COMPILE} mrproper
  [ -d "${OUT}" ] && rm -rf ${OUT}
  echo "${GREEN}***** Cleaning Done *****${NC}"
  pause 'continue'
  main
}

# Function to build kernel
build_kernel() {
  variant
  echo -e "${BGREEN}***** Compiling kernel *****${NC}"
  [ ! -d "${OUT}" ] && mkdir ${OUT}
  make -j$(nproc) -C $(pwd) ${KERNEL_MAKE_ENV} CROSS_COMPILE=${CROSS_COMPILE} $DEFCONFIG
  make -j$(nproc) -C $(pwd) ${KERNEL_MAKE_ENV} CROSS_COMPILE=${CROSS_COMPILE}

  # Check for different kernel image formats
  if [ -e arch/arm64/boot/Image.gz ]; then
    cp arch/arm64/boot/Image.gz ${OUT}/Image.gz
    echo -e "${GREEN}Kernel Image.gz found and copied!${NC}"
  elif [ -e arch/arm64/boot/Image ]; then
    cp arch/arm64/boot/Image ${OUT}/Image
    echo -e "${GREEN}Kernel Image found and copied!${NC}"
  elif [ -e arch/arm64/boot/zImage ]; then
    cp arch/arm64/boot/zImage ${OUT}/zImage
    echo -e "${GREEN}Kernel zImage found and copied!${NC}"
  elif [ -e arch/arm64/boot/Image.gz-dtb ]; then
    cp arch/arm64/boot/Image.gz-dtb ${OUT}/Image.gz-dtb
    echo -e "${GREEN}Kernel Image.gz-dtb found and copied!${NC}"
  else
    echo -e "${RED}No recognized kernel image format found!${NC}"
    pause 'return to Main menu'
    main
    return
  fi

  echo -e "${BGREEN}***** Kernel build complete! *****${NC}"
  pause 'continue'
  main
}


# Function to build dtbo.img
build_dtbo() {
  git clone https://github.com/avef1000/mkdtboimg.git $TOOLS/dtb
  chmod 755 $TOOLS/dtb/mkdtboimg.py
  cd $OUT
  $DTBTOOL create dtbo.img $DTB_DIR/*.dtbo
 main
}

# Function to build anykernel zip
anykernel3() {
  if [ ! -d ${TOOLS}/AnyKernel3 ]; then
    pause 'clone AnyKernel3 - Flashable Zip Template'
    git clone https://github.com/osm0sis/AnyKernel3 ${TOOLS}/AnyKernel3
  fi

  if [ -e ${K_DIR}/arch/arm64/boot/Image ]; then
    cd ${TOOLS}/AnyKernel3
    git reset --hard
    git clean -f
    cp ${K_DIR}/arch/arm64/boot/Image zImage
    sed -i "s/ExampleKernel by osm0sis/${VARIANT} kernel by $USER/g" anykernel.sh
    sed -i "s/=maguro/=/g" anykernel.sh
    sed -i "s/=toroplus/=/g" anykernel.sh
    sed -i "s/=toro/=/g" anykernel.sh
    sed -i "s/=tuna/=/g" anykernel.sh
    sed -i "s/platform\/omap\/omap_hsmmc\.0\/by-name\/boot/bootdevice\/by-name\/boot/g" anykernel.sh
    sed -i "s/backup_file/#backup_file/g" anykernel.sh
    sed -i "s/replace_string/#replace_string/g" anykernel.sh
    sed -i "s/insert_line/#insert_line/g" anykernel.sh
    sed -i "s/append_file/#append_file/g" anykernel.sh
    sed -i "s/patch_fstab/#patch_fstab/g" anykernel.sh
    sed -i "s/dump_boot/split_boot/g" anykernel.sh
    sed -i "s/write_boot/flash_boot/g" anykernel.sh
    zip -r9 ${K_DIR}/${VARIANT}_kernel_$(cat ${K_DIR}/include/config/kernel.release)_$(date '+%Y_%m_%d').zip * -x .git README.md *placeholder
    cd ${K_DIR}
    pause 'continue'
  else
    pause 'return to Main menu' 'Build kernel first!'
  fi
main
}

# Function to build boot image with AIK-Linux
build_boot_img() {
  git clone https://github.com/osm0sis/Android-Image-Kitchen.git $TOOLS/AIK-LINUX
  cp $STOCK_BOOT $AIK
  cd $AIK
  chmod 755 *
  ./unpackimg.sh boot.img

  # Handle different kernel image formats
  if [ -e ${K_DIR}/arch/arm64/boot/Image ]; then
    cp $K_DIR/arch/arm64/boot/Image split_image/boot.img-kernel
  elif [ -e ${K_DIR}/arch/arm64/boot/zImage ]; then
    cp $K_DIR/arch/arm64/boot/zImage split_image/boot.img-kernel
  elif [ -e ${K_DIR}/arch/arm64/boot/Image.gz-dtb ]; then
    cp $K_DIR/arch/arm64/boot/Image.gz-dtb split_image/boot.img-kernel
  else
    echo -e "${RED}No recognized kernel image format found for boot image!${NC}"
    pause 'return to Main menu'
    main
    return
  fi

  ./repackimg.sh
  ./cleanup.sh
  echo -e "${GREEN}Boot image built successfully with AIK-Linux!${NC}"
  pause 'continue'
  main
}


# Main function to display menu
main() {
  clear
  echo -e "${RED}${BOLD}==================================================${NC}"
  echo -e "${BLUE}${BOLD} Welcome to the Flame Kernel builder menu - ${menu_version} ${NC}"
  echo -e "${RED}${BOLD}==================================================${NC}"
  echo -e "${GREEN}${BOLD}1. Enter Your info${NC}"
  echo -e "${GREEN}${BOLD}2. Clean output directory${NC}"
  echo -e "${GREEN}${BOLD}3. Choose toolchain${NC}"
  echo -e "${GREEN}${BOLD}4. Coose defconfig${NC}"
  echo -e "${GREEN}${BOLD}5. Build kernel${NC}"
  echo -e "${GREEN}${BOLD}6. Build dtbo.img${NC}"
  echo -e "${GREEN}${BOLD}7. Build anykernel zip${NC}"
  echo -e "${GREEN}${BOLD}8. Build boot image with AIK-Linux${NC}"
  echo -e "${RED}${BOLD}X. Exit${NC}"
  echo -e "${RED}${BOLD}==================================================${NC}"

  read -p "$(echo -e ${YELLOW}${BOLD}Enter choice [ 1 - 8, X ]${NC}) " choice
  case $choice in
    1) get_user ;;
    2) clean ;;
    3) choose_toolchain ;;
    4) get_defconfig ;;
    5) build_kernel ;;
    6) build_dtbo ;;
    7) anykernel3 ;;
    8) build_boot_img ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}${BOLD}Error: Invalid selection${NC}"
       pause 'try again'
       main ;;
  esac
}

main
