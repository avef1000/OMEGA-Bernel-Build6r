#!/bin/bash
# Avraham Freeman kernel menu

# Define color codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color
UNDER_LINE='\033[4m' # Underline

# Function to print message
pnt_msg() {
  local color=$1
  shift
  echo -e "${color}${BOLD}$@${NC}"
}

# Variables to export
K_DIR="$(pwd)"
menu_version="v3.8"
TOOLCHAIN="${K_DIR}/toolchains"
TOOLS="${K_DIR}/toys"
AIK="${TOOLS}/AIK-LINUX"
STOCK_BOOT="${K_DIR}/stock-boot/*"
DTBTOOL="${TOOLS}/dtb/mkdtboimg.py"
DTB_DIR="${K_DIR}/arch/arm64/boot/dts/*/*/"
OUT="${K_DIR}/output"
export K_DIR TOOLCHAIN TOOLS AIK STOCK_BOOT DTBTOOL DTB_DIR OUT
export PLATFORM_VERSION= # please fill in
export ANDROID_MAJOR_VERSION= # please fill in
export VARIANT="omega-kernel" # type in name of your kernel or device

# Make directories
mkdir -p "$TOOLS"
mkdir -p "$OUT"
mkdir -p stock-boot

# Function to get user name
get_user() {
  echo "Hello and welcome to the Flame Kernel Builder"
  read -p "What is your name? (to be used in anykernel.zip and kernel variant): " name
  USER="$name"
  export USER
  main
}

# Press enter
pause() {
  read -p "${RED}Press ${BLUE}[Enter]${RED} key to ${1}...${NC}" fackEnterKey
}

# Function to clone GCC toolchain
clone_gcc() {
  echo -e "${RED}Cloning GCC toolchain...${NC}"
  git clone --branch android-9.0.0_r59 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 "${TOOLCHAIN}/aarch64-linux-android-4.9"
  export PATH="$(pwd)/toolchains/aarch64-linux-android-4.9/bin:$PATH"
  export CROSS_COMPILE="$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
  export GCC_AR="$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-ar"
  export GCC_NM="$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-nm"
  export GCC_OBJCOPY="$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-objcopy"
  export GCC_OBJDUMP="$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-objdump"
  export GCC_STRIP="$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-strip"
  echo "GCC toolchain cloned and PATH updated."
  main
}

# Function to clone Clang toolchain
clone_clang() {
  echo -e "${RED}Cloning Clang toolchain...${NC}"
  git clone --depth=1 https://github.com/kdrag0n/proton-clang.git "${TOOLCHAIN}/clang"
  export PATH="${TOOLCHAIN}/clang/bin:$PATH"
  export ARCH=arm64
  export CROSS_COMPILE="${TOOLCHAIN}/clang/bin/aarch64-linux-gnu-"
  export CROSS_COMPILE_ARM32="${TOOLCHAIN}/clang/bin/arm-linux-gnueabi-"
  export AR=llvm-ar
  export NM=llvm-nm
  export OBJCOPY=llvm-objcopy
  export OBJDUMP=llvm-objdump
  export STRIP=llvm-strip
  echo "Clang toolchain cloned and PATH updated."
  main
}

# Function to choose toolchain
choose_toolchain() {
  echo -e "${YELLOW}Please choose to build with Clang or GCC (based on your kernel)${NC}"
  echo -e "${RED}Enter toolchain [ 1 - 2 ]${NC}"
  read -p "1) GCC Toolchain
2) Clang Toolchain
Enter choice: " toolchain
  case $toolchain in
    1) clone_gcc ;;
    2) clone_clang ;;
    *) echo -e "${RED}Invalid option, returning to toolchain selection${NC}"
       choose_toolchain ;;
  esac
  main
}

# Function to get defconfig
get_defconfig() {
  echo "${RED}${BOLD}Available defconfig files:${NC}"
  ls "${KERNEL_DIR}/arch/arm64/configs/"
  read -p "Please type in the name of the defconfig you would like to use: " CHOICE
  DEFCONFIG="$CHOICE"
  export DEFCONFIG
  echo "Chosen defconfig $DEFCONFIG"
  main
}

# Function to clean
clean() {
  echo "${GREEN}***** Cleaning in Progress *****${NC}"
  make "${KERNEL_MAKE_ENV}" CROSS_COMPILE="${CROSS_COMPILE}" clean 
  make "${KERNEL_MAKE_ENV}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper
  [ -d "${OUT}" ] && rm -rf "${OUT}"
  echo "${GREEN}***** Cleaning Done *****${NC}"
  pause 'continue'
  main
}

# Function to build kernel
build_kernel() {
  echo -e "${GREEN}***** Compiling kernel *****${NC}"
  [ ! -d "${OUT}" ] && mkdir "${OUT}"
  make -j$(nproc) -C "$(pwd)" "${KERNEL_MAKE_ENV}" CROSS_COMPILE="${CROSS_COMPILE}" "$DEFCONFIG"
  make -j$(nproc) -C "$(pwd)" "${KERNEL_MAKE_ENV}" CROSS_COMPILE="${CROSS_COMPILE}"

  if [ -e arch/arm64/boot/Image.gz ]; then
    cp arch/arm64/boot/Image.gz "${OUT}/Image.gz"
    echo -e "${GREEN}Kernel Image.gz found and copied!${NC}"
  elif [ -e arch/arm64/boot/Image ]; then
    cp arch/arm64/boot/Image "${OUT}/Image"
    echo -e "${GREEN}Kernel Image found and copied!${NC}"
  elif [ -e arch/arm64/boot/zImage ]; then
    cp arch/arm64/boot/zImage "${OUT}/zImage"
    echo -e "${GREEN}Kernel zImage found and copied!${NC}"
  elif [ -e arch/arm64/boot/Image.gz-dtb ]; then
    cp arch/arm64/boot/Image.gz-dtb "${OUT}/Image.gz-dtb"
    echo -e "${GREEN}Kernel Image.gz-dtb found and copied!${NC}"
  else
    echo -e "${RED}No recognized kernel image format found!${NC}"
    pause 'return to Main menu'
    main
    return
  fi

  echo -e "${GREEN}***** Kernel build complete! *****${NC}"
  pause 'continue'
  main
}

# Function to build dtbo.img
build_dtbo() {
  git clone https://github.com/avef1000/mkdtboimg.git "${TOOLS}/dtb"
  chmod 755 "${TOOLS}/dtb/mkdtboimg.py"
  cd "${OUT}"
  "${DTBTOOL}" create dtbo.img "${DTB_DIR}"/*.dtbo
  main
}

# Function to build anykernel zip
anykernel3() {
  if [ ! -d "${TOOLS}/AnyKernel3" ]; then
    pause 'clone AnyKernel3 - Flashable Zip Template'
    git clone https://github.com/osm0sis/AnyKernel3 "${TOOLS}/AnyKernel3"
  fi

  if [ -e "${K_DIR}/arch/arm64/boot/Image" ]; then
    cd "${TOOLS}/AnyKernel3"
    git reset --hard
    git clean -f
    cp "${K_DIR}/arch/arm64/boot/Image" zImage
    sed -i "s/ExampleKernel by osm0sis/${VARIANT} kernel by ${USER}/g" anykernel.sh
    sed -i "s/=maguro/=/g" anykernel.sh
    sed -i "s|/dev/block/platform/omap/omap_hsmmc.0/by-name/boot|/dev/block/bootdevice/by-name/boot|g" anykernel.sh
    zip -r9 "${OUT}/${VARIANT}-$(date +%Y%m%d).zip" . -x README.md -x .gitignore -x .git/\*
  elif [ -e "${K_DIR}/arch/arm64/boot/Image.gz-dtb" ]; then
    cd "${TOOLS}/AnyKernel3"
    git reset --hard
    git clean -f
    cp "${K_DIR}/arch/arm64/boot/Image.gz-dtb" zImage
    sed -i "s/ExampleKernel by osm0sis/${VARIANT} kernel by ${USER}/g" anykernel.sh
    sed -i "s/=maguro/=/g" anykernel.sh
    sed -i "s|/dev/block/platform/omap/omap_hsmmc.0/by-name/boot|/dev/block/bootdevice/by-name/boot|g" anykernel.sh
    zip -r9 "${OUT}/${VARIANT}-$(date +%Y%m%d).zip" . -x README.md -x .gitignore -x .git/\*
  else
    echo -e "${RED}No kernel image found to package!${NC}"
    pause 'return to Main menu'
    main
    return
  fi

  echo -e "${GREEN}Anykernel3 zip built and stored in ${OUT}${NC}"
  pause 'return to Main menu'
  main
}

# Function to set up AIK
aik() {
  echo -e "${YELLOW}Please select option to unpack or repack boot.img${NC}"
  echo -e "${RED}Enter selection [ 1 - 2 ]${NC}"
  read -p "1) Unpack
2) Repack
Enter choice: " choice
  case $choice in
    1) unpack_aik ;;
    2) repack_aik ;;
    *) echo -e "${RED}Invalid option${NC}"
       aik ;;
  esac
}

# Function to unpack AIK
unpack_aik() {
  git clone https://github.com/osm0sis/Android-Image-Kitchen.git "${TOOLS}/AIK-LINUX"
  chmod 755 "${AIK}"/*
  cd "${AIK}"
  cp "${STOCK_BOOT}"/*.img .
  ./unpackimg.sh --nosudo
  main
}

# Function to repack AIK
repack_aik() {
  cd "${AIK}"
  ./repackimg.sh
  cp image-new.img "${OUT}/new-boot.img"
  echo -e "${GREEN}Patched image found at ${OUT}${NC}"
  main
}

# Main menu
main() {
  clear
  echo -e "${UNDER_LINE}${BLUE}***** FLAME KERNEL MENU *****${NC}"
  echo -e "${RED}Please select a menu option:${NC}"
  echo -e "${BOLD}${YELLOW}0. Exit
1. Get Name
2. Clone Toolchain
3. Get Defconfig
4. Clean
5. Build Kernel
6. Build DTBO.img
7. AnyKernel3
8. Create output dir
9. AIK-LINUX${NC}"
  read -p "Enter choice: " opt
  case $opt in
    0) exit 0 ;;
    1) get_user ;;
    2) choose_toolchain ;;
    3) get_defconfig ;;
    4) clean ;;
    5) build_kernel ;;
    6) build_dtbo ;;
    7) anykernel3 ;;
    8) mkdir -p "${OUT}" ;;
    9) aik ;;
    *) echo -e "${RED}Invalid option${NC}"
       main ;;
  esac
}

# Run the main function
main
