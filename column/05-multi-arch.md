# 05 - 多架构支持

## 为什么需要多架构

Android 设备使用不同的 CPU 架构：

| 架构 | 使用场景 | 模拟器用途 |
|------|---------|-----------|
| arm64 | 真实手机、平板 | 在 ARM 主机或通过翻译运行 |
| x86_64 | Chromebook、极少数平板 | 在 x86 主机上高性能运行 |

matrix 同时支持 arm64 和 x86_64 两个架构，这让开发者可以：
- **x86_64**：日常开发时使用，在 Intel/AMD 主机上性能最好（KVM 加速）
- **arm64**：验证 ARM 特有行为、测试 ARM 库兼容性

## 两个架构的完整对比

### BoardConfig 对比

**matrix_arm64/BoardConfig.mk：**

```makefile
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

**matrix_x86_64/BoardConfig.mk：**

```makefile
TARGET_CPU_ABI := x86_64
TARGET_ARCH := x86_64
TARGET_ARCH_VARIANT := x86_64
TARGET_2ND_ARCH_VARIANT := x86_64

include device/matrix/board/BoardConfigCommon.mk

BOARD_USERDATAIMAGE_PARTITION_SIZE := 576716800
```

差异点：

| 配置项 | arm64 | x86_64 |
|--------|-------|--------|
| `TARGET_ARCH` | arm64 | x86_64 |
| `TARGET_ARCH_VARIANT` | armv8-a | x86_64 |
| `TARGET_CPU_VARIANT` | generic | （未设置，使用默认） |
| `TARGET_CPU_ABI` | arm64-v8a | x86_64 |
| `BOARD_BOOTIMAGE_PARTITION_SIZE` | 0x02000000 (32MB) | （未设置，使用默认） |
| `BOARD_USERDATAIMAGE_PARTITION_SIZE` | 576716800 | 576716800 |

关键观察：
- x86_64 的 `TARGET_CPU_VARIANT` 不需要设置，goldfish 会自动处理
- x86_64 没有定义 boot 分区大小，因为 goldfish 的 x86_64 配置有默认值
- userdata 大小相同（576716800 字节 ≈ 550 MB）

### details.mk 对比

**matrix_arm64/details.mk：**

```makefile
include device/generic/goldfish/board/kernel/arm64.mk

PRODUCT_PROPERTY_OVERRIDES += \
       vendor.rild.libpath=/vendor/lib64/libgoldfish-ril.so

PRODUCT_COPY_FILES += \
    device/generic/goldfish/board/fstab/arm:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.ranchu \
    device/generic/goldfish/board/fstab/arm:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.ranchu \
    $(EMULATOR_KERNEL_FILE):kernel-ranchu \
    device/generic/goldfish/data/etc/advancedFeatures.ini:advancedFeatures.ini \
```

**matrix_x86_64/details.mk：**

```makefile
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

差异点：

| 配置项 | arm64 | x86_64 |
|--------|-------|--------|
| 内核 mk | `kernel/arm64.mk` | `kernel/x86_64.mk` |
| fstab 源 | `fstab/arm` | `fstab/x86` |
| `ADVANCED_FEATURES_FILE` | 未定义（直接写字符串） | 定义为变量 |
| `PRODUCT_COPY_FILES` 顺序 | fstab 在前 | advancedFeatures 在前 |

一个有趣的细节：x86_64 用了 `fstab/x86` 而不是 `fstab/x86_64`。这是因为 goldfish 的 x86_64 启动流程复用了 x86 的 fstab 文件。

### Product mk 对比

**matrix_arm64.mk：**

```makefile
BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE ?= $(shell expr 1536 \* 1048576 )
BOARD_SUPER_PARTITION_SIZE := $(shell expr $(BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE) + 8388608 )

PRODUCT_MODEL := Matrix Phone arm64
```

**matrix_x86_64.mk：**

```makefile
BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE ?= $(shell expr 1792 \* 1048576 )
BOARD_SUPER_PARTITION_SIZE := $(shell expr $(BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE) + 8388608 )

PRODUCT_MODEL := Matrix Phone x86_64
```

差异只有两处：
1. **动态分区大小**：arm64 是 1536 MB，x86_64 是 1792 MB（x86_64 通常需要更多空间，因为包含更多翻译库）
2. **产品型号名**：`Matrix Phone arm64` vs `Matrix Phone x86_64`

其余（品牌、制造商、继承链）完全相同。

## 公共配置的抽取策略

matrix 的目录结构体现了一个清晰的抽取原则：

```
board/
├── BoardConfigCommon.mk           ← 两个架构完全共享
├── matrix_arm64/
│   ├── BoardConfig.mk             ← 架构特有的变量定义
│   └── details.mk                 ← 架构特有的内核/fstab
└── matrix_x86_64/
    ├── BoardConfig.mk
    └── details.mk
```

**什么放在公共配置中**：
- goldfish 继承（`include device/generic/goldfish/board/BoardConfigCommon.mk`）
- 所有架构都一样的设置（bootloader 名称覆盖）

**什么放在架构专属配置中**：
- CPU 架构变量（`TARGET_ARCH`、`TARGET_CPU_ABI`）
- 分区大小（如果不同）
- 内核和 fstab 路径

**什么放在 Product mk 中**：
- 产品品牌（不同架构可以有不同品牌，但 matrix 保持一致）
- 动态分区大小（因架构不同）

## 如何选择编译哪个架构

### 开发推荐：x86_64

```bash
lunch matrix_x86_64-trunk_staging-eng
m -j$(nproc)
emulator
```

优势：
- 在 x86 主机上通过 KVM 加速，启动和运行速度快
- 支持快速启动（Quick Boot / Snapshot）
- 开发调试体验最好

### 兼容性验证：arm64

```bash
lunch matrix_arm64-trunk_staging-eng
m -j$(nproc)
emulator
```

场景：
- 测试 ARM 原生库的兼容性
- 验证 ARM 特有的行为
- 验证 native 代码在 ARM 上的执行

注意：arm64 模拟器在 x86 主机上通过翻译层运行，速度明显比 x86_64 慢。

### 两者切换

切换架构只需重新 lunch：

```bash
# 当前是 x86_64，切换到 arm64
lunch matrix_arm64-trunk_staging-eng
m -j$(nproc)
emulator
```

构建系统会根据 lunch 选择读取不同的 BoardConfig 和 Product mk，输出到 `out/target/product/matrix_arm64/` 或 `out/target/product/matrix_x86_64/`。

## 完整继承链对比图

```
matrix_arm64.mk                          matrix_x86_64.mk
    │                                         │
    ├─ inherit-product                        ├─ inherit-product
    │  core_64_bit_only.mk                    │  core_64_bit_only.mk
    │                                         │
    ├─ inherit-product                        ├─ inherit-product
    │  board/matrix_arm64/details.mk          │  board/matrix_x86_64/details.mk
    │    │                                    │    │
    │    ├─ include kernel/arm64.mk           │    ├─ include kernel/x86_64.mk
    │    ├─ fstab/arm                         │    ├─ fstab/x86
    │    └─ libgoldfish-ril.so                │    └─ libgoldfish-ril.so
    │                                         │
    ├─ inherit-product                        ├─ inherit-product
    │  goldfish/product/phone.mk              │  goldfish/product/phone.mk
    │    └─ (完全相同)                         │    └─ (完全相同)
    │                                         │
    ├─ BOARD_SUPER: 1544 MB                   ├─ BOARD_SUPER: 1800 MB
    └─ MODEL: Matrix Phone arm64              └─ MODEL: Matrix Phone x86_64
```

goldfish/product/phone.mk 之后的继承链对两个架构完全相同，差异仅限于：
1. 内核二进制和模块
2. fstab 文件
3. 动态分区大小
4. 产品型号名

## 如果要添加第三个架构

假设要添加一个 `matrix_riscv64` 架构，需要：

1. 创建 `board/matrix_riscv64/BoardConfig.mk` — 定义 RISC-V 架构变量
2. 创建 `board/matrix_riscv64/details.mk` — 指向 goldfish 的 RISC-V 内核和 fstab（如果 goldfish 支持）
3. 创建 `product/matrix_riscv64.mk` — 产品定义，设置分区大小和品牌
4. 在 `AndroidProducts.mk` 中注册新产品和 lunch 组合

因为公共配置已经抽取到 `BoardConfigCommon.mk`，新架构只需要填写差异部分。

## 小结

- matrix 通过目录结构分离公共配置和架构专属配置，代码重复降到最低
- 两个架构的 BoardConfig 差异在 CPU 变量和分区大小；details.mk 差异在内核和 fstab 路径；Product mk 差异在分区大小和型号名
- 日常开发推荐 x86_64（KVM 加速），兼容性测试使用 arm64
- 添加新架构只需新增子目录，公共配置自动共享

## 基础搭建部分完结

到这里，第一部分"基础搭建"的 5 篇文章全部完成。我们完整解析了 `device/matrix` 的所有文件，涵盖了：

1. AOSP 设备定制的全景概览
2. 产品注册与 lunch 机制
3. Board 配置与硬件定义
4. Product 配置与软件产品定义
5. 多架构支持的设计策略

接下来的第二部分将在这个基础上，逐步添加系统属性、资源叠加、init 脚本、SEPolicy 等定制能力。
