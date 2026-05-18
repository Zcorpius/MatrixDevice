# Matrix Device Configuration

Matrix 是一个基于 AOSP 16 的自定义 Android 模拟器设备配置，继承自 `device/generic/goldfish` 实现，支持在 Android Emulator 中运行。

## 目录结构

```
device/matrix/
├── AndroidProducts.mk                        # 产品注册入口文件
├── vendorsetup.sh                            # lunch 组合注册脚本
├── README.md                                 # 本文档
├── board/
│   ├── BoardConfigCommon.mk                  # 板级通用配置（继承 goldfish）
│   ├── matrix_arm64/
│   │   ├── BoardConfig.mk                    # ARM64 架构板级配置
│   │   └── details.mk                        # ARM64 内核、fstab 等详细信息
│   └── matrix_x86_64/
│       ├── BoardConfig.mk                    # x86_64 架构板级配置
│       └── details.mk                        # x86_64 内核、fstab 等详细信息
└── product/
    ├── matrix_arm64.mk                       # ARM64 产品定义
    └── matrix_x86_64.mk                      # x86_64 产品定义
```

## 文件说明

### AndroidProducts.mk

**作用**: 产品注册入口文件，告诉 Android 构建系统本目录下有哪些可构建的产品。

注册了两个产品：
- `matrix_arm64` — ARM64 架构模拟器
- `matrix_x86_64` — x86_64 架构模拟器

### vendorsetup.sh

**作用**: 保留文件以确保构建系统能扫描到此设备目录。AOSP 15+ 中 lunch 组合通过 `AndroidProducts.mk` 中的 `COMMON_LUNCH_CHOICES` 注册，不再使用已过时的 `add_lunch_combo`。

### COMMON_LUNCH_CHOICES (在 AndroidProducts.mk 中)

**作用**: 向 `lunch` 菜单注册可用的构建组合。AOSP 15 使用 `<product>-trunk_staging-<variant>` 格式。

注册了 4 个 lunch 组合：

| 组合名 | 说明 |
|--------|------|
| `matrix_arm64-trunk_staging-userdebug` | ARM64 调试版本 |
| `matrix_arm64-trunk_staging-eng` | ARM64 工程版本 |
| `matrix_x86_64-trunk_staging-userdebug` | x86_64 调试版本 |
| `matrix_x86_64-trunk_staging-eng` | x86_64 工程版本 |

### board/BoardConfigCommon.mk

**作用**: 所有 Matrix 设备共享的板级配置。继承自 `device/generic/goldfish/board/BoardConfigCommon.mk`，获得以下能力：

- 动态分区（super.img）支持
- OpenGL ES 模拟
- 非 A/B 升级模式
- WiFi 模拟（mac80211）
- Verified Boot 支持
- QEMU 镜像构建

同时覆盖了 `TARGET_BOOTLOADER_BOARD_NAME` 为 `matrix_$(TARGET_ARCH)`。

### board/matrix_arm64/BoardConfig.mk

**作用**: ARM64 架构专用板级配置，定义：
- `TARGET_ARCH := arm64`，ARMv8-A 架构
- 包含 `BoardConfigCommon.mk` 通用配置
- 分区大小：boot 32MB，userdata ~550MB

### board/matrix_arm64/details.mk

**作用**: ARM64 架构的产品级详细信息，以 `inherit-product` 方式被产品 mk 引用：
- 包含 goldfish 的 ARM64 内核配置 (`arm64.mk`)
- 设置 RIL 库路径
- 复制 ARM fstab、内核镜像、advancedFeatures.ini 等文件

### board/matrix_x86_64/BoardConfig.mk

**作用**: x86_64 架构专用板级配置，定义：
- `TARGET_ARCH := x86_64`
- 包含 `BoardConfigCommon.mk` 通用配置
- userdata 分区 ~550MB

### board/matrix_x86_64/details.mk

**作用**: x86_64 架构的产品级详细信息：
- 包含 goldfish 的 x86_64 内核配置 (`x86_64.mk`)
- 设置 RIL 库路径
- 复制 x86 fstab、内核镜像、advancedFeatures.ini 等文件

### product/matrix_arm64.mk

**作用**: ARM64 产品完整定义，构建链如下：

```
matrix_arm64.mk
├── core_64_bit_only.mk (AOSP 纯 64 位支持)
├── board/matrix_arm64/details.mk (内核、fstab)
│   └── goldfish/board/kernel/arm64.mk
└── goldfish/product/phone.mk (完整手机产品栈)
    ├── goldfish/product/handheld.mk
    │   ├── base_handheld.mk → generic_system.mk, handheld_product.mk, handheld_vendor.mk
    │   ├── handheld_system_ext.mk
    │   └── aosp_product.mk
    └── goldfish/product/base_phone.mk
        ├── telephony_system_ext.mk
        ├── telephony_vendor.mk
        └── goldfish/product/generic.mk (HAL 包、驱动、权限等)
```

### product/matrix_x86_64.mk

**作用**: x86_64 产品完整定义，结构与 ARM64 版本对称，区别在于架构和 board details 引用。

## 架构设计

### 继承关系

```
                          ┌─────────────────────┐
                          │   AOSP Build System │
                          └─────────┬───────────┘
                                    │
                          ┌─────────▼───────────┐
                          │  AndroidProducts.mk  │  ← 注册产品
                          └─────────┬───────────┘
                                    │
                 ┌──────────────────┼──────────────────┐
                 │                                     │
       ┌─────────▼─────────┐               ┌──────────▼──────────┐
       │  matrix_arm64.mk   │               │  matrix_x86_64.mk   │
       └─────────┬─────────┘               └──────────┬──────────┘
                 │                                     │
      ┌──────────┼──────────┐              ┌──────────┼──────────┐
      │          │          │              │          │          │
  core_64bit  board/    goldfish/     core_64bit  board/    goldfish/
     only     arm64/    phone.mk        only     x86_64/    phone.mk
      │      details.mk                         details.mk
      │          │                                  │
      │    goldfish/board/                    goldfish/board/
      │    kernel/arm64.mk                    kernel/x86_64.mk
      │
      └──► board/matrix_arm64/BoardConfig.mk
               │
         BoardConfigCommon.mk ──► goldfish/board/BoardConfigCommon.mk
                                       │
                                 BoardConfigGsiCommon.mk
```

### 与 goldfish 的关系

Matrix **不修改** goldfish 的任何文件，完全通过继承（`inherit-product` / `include`）复用 goldfish 的实现：

| 功能 | 来源 |
|------|------|
| 内核 (6.6) | `device/generic/goldfish/board/kernel/` |
| HAL 包 (音频、相机、传感器等) | `device/generic/goldfish/product/generic.mk` |
| 手机产品栈 (telephony、handheld) | `device/generic/goldfish/product/phone.mk` |
| 分区布局、动态分区 | `device/generic/goldfish/board/BoardConfigCommon.mk` |
| OpenGL/Vulkan 模拟 | goldfish BoardConfigCommon |
| WiFi/蓝牙/RIL 模拟 | goldfish generic.mk |
| fstab、init 脚本 | `device/generic/goldfish/` |
| sepolicy | `device/generic/goldfish/sepolicy/` |

Matrix 仅覆盖了：
- 产品品牌信息（`PRODUCT_BRAND`, `PRODUCT_NAME`, `PRODUCT_DEVICE`, `PRODUCT_MODEL`, `PRODUCT_MANUFACTURER`）
- Bootloader 板名（`TARGET_BOOTLOADER_BOARD_NAME := matrix_$(TARGET_ARCH)`）

## 使用方法

### 1. 初始化构建环境

```bash
cd <AOSP_ROOT>
source build/envsetup.sh
```

### 2. 选择产品 (lunch)

```bash
# ARM64 架构
lunch matrix_arm64-trunk_staging-userdebug

# 或 x86_64 架构
lunch matrix_x86_64-trunk_staging-userdebug
```

### 3. 编译

```bash
m -j$(nproc)
```

### 4. 运行模拟器

```bash
emulator
```

## Lunch 组合列表

执行 `lunch` 后可以看到 Matrix 相关的组合：

```
- matrix_arm64-trunk_staging-userdebug
- matrix_arm64-trunk_staging-eng
- matrix_x86_64-trunk_staging-userdebug
- matrix_x86_64-trunk_staging-eng
```

- **userdebug**: 带 root 权限和调试工具的版本，适合日常开发调试
- **eng**: 包含更多工程调试工具的版本，适合底层开发
