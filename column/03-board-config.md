# 03 - Board 配置详解

## Board 配置的作用

如果说 `AndroidProducts.mk` 是设备的"名片"，那 `BoardConfig.mk` 就是设备的"硬件规格表"。它告诉构建系统：

- 这台设备使用什么 CPU 架构
- 存储分区怎么划分
- 用什么内核
- 启动方式是什么（A/B 还是 Non-A/B）
- 是否支持动态分区

Board 配置在编译时由 Soong/Make 构建系统读取，决定生成什么样的镜像文件。

## matrix 的 Board 配置结构

```
board/
├── BoardConfigCommon.mk        # 两个架构共享的公共配置
├── matrix_arm64/
│   ├── BoardConfig.mk           # ARM64 专属配置
│   └── details.mk               # ARM64 内核和文件系统细节
└── matrix_x86_64/
    ├── BoardConfig.mk           # x86_64 专属配置
    └── details.mk               # x86_64 内核和文件系统细节
```

设计思路：**公共部分抽到 `BoardConfigCommon.mk`，架构差异放在各自的子目录中**。

## 逐文件解析

### BoardConfigCommon.mk — 公共配置

```makefile
# device/matrix/board/BoardConfigCommon.mk

include device/generic/goldfish/board/BoardConfigCommon.mk

TARGET_BOOTLOADER_BOARD_NAME := matrix_$(TARGET_ARCH)
```

只有两行有效代码，但背后承载了很多：

**第一行：继承 goldfish 公共 Board 配置**

goldfish 的 `BoardConfigCommon.mk` 为我们定义了以下内容：

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `BUILD_EMULATOR_OPENGL` | true | 编译 OpenGL ES 模拟库 |
| `USE_OPENGL_RENDERER` | true | 使用 OpenGL 渲染器 |
| `BUILD_QEMU_IMAGES` | true | 构建 QEMU 镜像 |
| `TARGET_NO_BOOTLOADER` | true | 无真实 bootloader |
| `BOARD_BUILD_SYSTEM_ROOT_IMAGE` | true | system 分区作为 root |
| `AB_OTA_UPDATER` | false | Non-A/B 升级方式 |

goldfish 还定义了 **动态分区方案**：

```
super.img 包含:
├── system        (系统分区)
├── system_dlkm   (系统内核模块)
├── system_ext    (系统扩展)
├── product       (产品分区)
└── vendor        (厂商分区)
```

以及 Verified Boot (AVB) 配置、WiFi 模拟（mac80211_hwsim）和 vendor boot 镜像版本等。

**第二行：覆盖 bootloader 名称**

```makefile
TARGET_BOOTLOADER_BOARD_NAME := matrix_$(TARGET_ARCH)
```

goldfish 默认设置 `TARGET_BOOTLOADER_BOARD_NAME := goldfish_$(TARGET_ARCH)`。我们将其覆盖为 `matrix_arm64` 或 `matrix_x86_64`，这样在系统属性中看到的 bootloader 名称就是我们自己的。

### matrix_arm64/BoardConfig.mk — ARM64 配置

```makefile
# device/matrix/board/matrix_arm64/BoardConfig.mk

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_VARIANT := generic
TARGET_CPU_ABI := arm64-v8a

TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_VARIANT := generic

include device/matrix/board/BoardConfigCommon.mk

BOARD_BOOTIMAGE_PARTITION_SIZE := 0x02000000
BOARD_USERDATAIMAGE_PARTITION_SIZE := 576716800
```

**架构定义（必须项）：**

| 变量 | 值 | 说明 |
|------|-----|------|
| `TARGET_ARCH` | arm64 | 主架构 |
| `TARGET_ARCH_VARIANT` | armv8-a | 架构变体 |
| `TARGET_CPU_VARIANT` | generic | CPU 优化级别 |
| `TARGET_CPU_ABI` | arm64-v8a | 应用二进制接口 |

- `TARGET_CPU_VARIANT := generic` 表示不做特定 CPU 优化，适用于模拟器
- 真机上通常会设为 `cortex-a76` 之类的值
- `TARGET_2ND_*` 变量用于 64/32 位双架构支持，在 `core_64_bit_only` 模式下第二架构不生效，但保留定义不影响

**分区大小：**

```makefile
BOARD_BOOTIMAGE_PARTITION_SIZE := 0x02000000   # 32 MB
BOARD_USERDATAIMAGE_PARTITION_SIZE := 576716800  # ~550 MB
```

- boot 分区 32MB，存放内核和 ramdisk
- userdata 分区约 550MB，存放用户数据
- system、vendor 等分区的大小在 `product/matrix_arm64.mk` 中通过动态分区配置

**注意**：BoardConfig 中使用 `include`（直接包含），而 product mk 中使用 `inherit-product`（产品继承）。这是 AOSP 构建系统的一个重要区分——Board 配置是 Make 的直接 include，Product 配置是 Soong 的 inherit-product 机制。

### matrix_arm64/details.mk — 内核与文件系统细节

```makefile
# device/matrix/board/matrix_arm64/details.mk

include device/generic/goldfish/board/kernel/arm64.mk

PRODUCT_PROPERTY_OVERRIDES += \
       vendor.rild.libpath=/vendor/lib64/libgoldfish-ril.so

PRODUCT_COPY_FILES += \
    device/generic/goldfish/board/fstab/arm:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.ranchu \
    device/generic/goldfish/board/fstab/arm:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.ranchu \
    $(EMULATOR_KERNEL_FILE):kernel-ranchu \
    device/generic/goldfish/data/etc/advancedFeatures.ini:advancedFeatures.ini \
```

**内核继承：**

`goldfish/board/kernel/arm64.mk` 定义了：
- 内核版本：6.12
- 内核镜像路径：从预编译位置获取
- 内核模块：virtio 系列驱动（virtio_net、virtio_blk、virtio_gpu 等）
- 内核命令行参数

**RIL 库：**

```makefile
PRODUCT_PROPERTY_OVERRIDES += \
       vendor.rild.libpath=/vendor/lib64/libgoldfish-ril.so
```

指定 RIL（Radio Interface Layer）库路径。goldfish 提供了一个模拟的 RIL 实现，让模拟器可以模拟电话功能。

**文件拷贝：**

`PRODUCT_COPY_FILES` 是 AOSP 构建系统中将文件打包进镜像的标准方式，格式为 `源路径:目标路径`：

| 源 | 目标 | 说明 |
|----|------|------|
| `fstab/arm` | `vendor_ramdisk/.../fstab.ranchu` | 第一阶段挂载表 |
| `fstab/arm` | `vendor/etc/fstab.ranchu` | 运行时挂载表 |
| `$(EMULATOR_KERNEL_FILE)` | `kernel-ranchu` | 内核镜像 |
| `advancedFeatures.ini` | `advancedFeatures.ini` | 模拟器特性配置 |

fstab 文件在 Android 启动的两个阶段都需要：
1. **第一阶段（vendor ramdisk）**：init 进程的早期阶段，需要挂载基本分区
2. **运行时（vendor/etc）**：系统启动后，vold 等服务需要读取挂载信息

### matrix_x86_64/BoardConfig.mk — x86_64 配置

```makefile
# device/matrix/board/matrix_x86_64/BoardConfig.mk

TARGET_CPU_ABI := x86_64
TARGET_ARCH := x86_64
TARGET_ARCH_VARIANT := x86_64
TARGET_2ND_ARCH_VARIANT := x86_64

include device/matrix/board/BoardConfigCommon.mk

BOARD_USERDATAIMAGE_PARTITION_SIZE := 576716800
```

与 ARM64 版本的关键差异：
- 架构变量全部改为 x86_64
- **没有定义 `BOARD_BOOTIMAGE_PARTITION_SIZE`**（x86_64 使用 goldfish 默认值）
- x86_64 不需要 `TARGET_CPU_VARIANT`（goldfish 默认处理）

### matrix_x86_64/details.mk — x86_64 内核细节

```makefile
# device/matrix/board/matrix_x86_64/details.mk

include device/generic/goldfish/board/kernel/x86_64.mk

PRODUCT_PROPERTY_OVERRIDES += \
       vendor.rild.libpath=/vendor/lib64/libgoldfish-ril.so

ADVANCED_FEATURES_FILE := advancedFeatures.ini

PRODUCT_COPY_FILES += \
    device/generic/goldfish/data/etc/$(ADVANCED_FEATURES_FILE):advancedFeatures.ini \
    $(EMULATOR_KERNEL_FILE):kernel-ranchu \
    device/generic/goldfish/board/fstab/x86:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.ranchu \
    device/generic/goldfish/board/fstab/x86:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.ranchu \
```

与 ARM64 版本的差异：
- 内核配置继承 `kernel/x86_64.mk`
- fstab 使用 `fstab/x86`（不是 x86_64，因为 goldfish 的 x86_64 复用 x86 的 fstab）
- `PRODUCT_COPY_FILES` 的条目顺序略有不同，但功能等价

## BoardConfig 的 include 继承链

以 ARM64 为例，完整的 include 链路：

```
lunch 选择 matrix_arm64
    │
    ▼
product/matrix_arm64.mk
    │ inherit-product
    ▼
board/matrix_arm64/details.mk
    │ include
    ▼
goldfish/board/kernel/arm64.mk
    │ (定义内核路径、模块)
    │
board/matrix_arm64/BoardConfig.mk
    │ include
    ▼
board/BoardConfigCommon.mk
    │ include
    ▼
goldfish/board/BoardConfigCommon.mk
    │ include
    ▼
build/make/target/board/BoardConfigGsiCommon.mk
    │ (GSI 通用配置)
```

每一层都在上一层的基础上追加或覆盖配置。matrix 的 BoardConfig 只在 goldfish 的基础上改了一个 `TARGET_BOOTLOADER_BOARD_NAME`，其余全部复用。

## 分区布局总结

matrix 最终的分区方案：

| 分区 | 大小 | 说明 |
|------|------|------|
| boot | 32 MB (arm64) | 内核 + ramdisk |
| userdata | ~550 MB | 用户数据 |
| vendor_boot | goldfish 默认 | vendor ramdisk |
| super | 动态 | 包含以下子分区： |
| ├─ system | 动态 | Android 框架 |
| ├─ system_dlkm | 动态 | 系统内核模块 |
| ├─ system_ext | 动态 | 系统扩展 |
| ├─ product | 动态 | 产品定制 |
| └─ vendor | 动态 | 厂商/HAL |

super 分区的总大小在 `product/matrix_arm64.mk` 中定义，下一篇文章会详细解析。

## 小结

- Board 配置通过 `include` 直接包含，而非 `inherit-product`
- matrix 的 Board 配置几乎完全继承 goldfish，只覆盖了 bootloader 名称
- `details.mk` 负责连接内核、fstab 和必要的文件拷贝
- ARM64 和 x86_64 的 Board 配置结构相同，差异仅在架构变量和内核/fstab 路径

## 下一步

[04 - Product 配置详解](04-product-config.md)：详解产品品牌、动态分区大小和 inherit-product 继承链。
