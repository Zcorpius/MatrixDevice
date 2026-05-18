# 04 - Product 配置详解

## Product 配置的作用

如果说 Board 配置描述了硬件，那 Product 配置描述的就是 **软件产品**——这台设备叫什么名字、预装什么应用、启用什么功能、分区分配多大空间。

Product 配置使用 Soong 构建系统的 `inherit-product` 机制，这与 Board 配置使用的 Make `include` 机制有本质区别：

| | Board 配置 | Product 配置 |
|---|-----------|-------------|
| 机制 | Make `include`（直接展开） | Soong `inherit-product`（有去重和排序） |
| 作用域 | 编译期变量 | 产品属性变量 |
| 重复处理 | 无（可能导致重复定义） | 自动去重 |
| 执行顺序 | 按书写顺序 | Soong 控制顺序 |

## matrix_arm64.mk 完整解析

```makefile
# device/matrix/product/matrix_arm64.mk

PRODUCT_USE_DYNAMIC_PARTITIONS := true

PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed

BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE ?= $(shell expr 1536 \* 1048576 )
BOARD_SUPER_PARTITION_SIZE := $(shell expr $(BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE) + 8388608 )

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

$(call inherit-product, device/matrix/board/matrix_arm64/details.mk)

$(call inherit-product, device/generic/goldfish/product/phone.mk)

PRODUCT_BRAND := Matrix
PRODUCT_NAME := matrix_arm64
PRODUCT_DEVICE := matrix_arm64
PRODUCT_MODEL := Matrix Phone arm64
PRODUCT_MANUFACTURER := Matrix
```

逐段解析：

### 1. 动态分区配置

```makefile
PRODUCT_USE_DYNAMIC_PARTITIONS := true

BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE ?= $(shell expr 1536 \* 1048576 )
BOARD_SUPER_PARTITION_SIZE := $(shell expr $(BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE) + 8388608 )
```

**动态分区（Dynamic Partitions** 是 Android 10 引入的分区管理方式。传统方式中，system、vendor 等分区大小固定，而动态分区将它们放入一个 super 分区中，运行时动态分配空间。

```
super.img (1544 MB)
├── system_ext    (~200 MB)
├── system        (~800 MB)
├── product       (~150 MB)
├── vendor        (~300 MB)
└── system_dlkm   (~50 MB)
```

- `BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE`：动态分区的总可用空间，1536 MB
- `BOARD_SUPER_PARTITION_SIZE`：super 分区的物理大小 = 1536 MB + 8 MB（8 MB 用于存储分区元数据）
- `?=` 表示仅在未定义时赋值，允许被外部覆盖

### 2. 产物路径校验

```makefile
PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed
```

AOSP 构建系统会检查编译产物是否放在正确的分区路径下。`relaxed` 模式放宽了这个检查，允许一些不在白名单中的文件存在。对于自定义设备，这个设置可以避免大量无关的路径校验错误。

### 3. 继承 core_64_bit_only

```makefile
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
```

`$(SRC_TARGET_DIR)` 展开为 `build/make/target`，所以实际路径是 `build/make/target/product/core_64_bit_only.mk`。

这个文件做了以下事情：

```makefile
# core_64_bit_only.mk 的关键定义
PRODUCT_COPY_FILES += system/core/rootdir/init.zygote64.rc:system/etc/init/zygote64.rc

# 设置属性：使用 64 位 zygote
PRODUCT_SYSTEM_PROPERTIES += ro.zygote=zygote64

# 启用 64 位 dex2oat
PRODUCT_SYSTEM_PROPERTIES += dalvik.vm.dex2oat64.enabled=true

# 只支持 64 位应用
PRODUCT_SYSTEM_PROPERTIES += ro.product.cpu.abilist=arm64-v8a
PRODUCT_SYSTEM_PROPERTIES += ro.product.cpu.abilist64=arm64-v8a
```

效果：
- 只运行 64 位 zygote（应用孵化器）
- 只安装和运行 64 位应用
- 使用 64 位 dex2oat 编译器（ART 运行时）

这意味着 matrix 设备 **不支持 32 位应用**。如果要支持，需要改用 `core_64_bit.mk`（同时包含 32/64 位）。

### 4. 继承 board details

```makefile
$(call inherit-product, device/matrix/board/matrix_arm64/details.mk)
```

这一行引入了上一篇文章分析的 `details.mk`，将内核配置、fstab 和文件拷贝规则纳入产品构建。

注意：`details.mk` 中使用了 `PRODUCT_PROPERTY_OVERRIDES` 和 `PRODUCT_COPY_FILES`，这些是产品变量，所以用 `inherit-product` 而非 `include`。

### 5. 继承 goldfish phone 产品栈

```makefile
$(call inherit-product, device/generic/goldfish/product/phone.mk)
```

这是最重要的一行。它拉起了 goldfish 的 **完整手机产品栈**。继承链展开如下：

```
goldfish/product/phone.mk
├── goldfish/product/handheld.mk
│   ├── goldfish/product/base_handheld.mk     # 手持设备基础包
│   ├── build/.../generic_system.mk           # 系统核心包（Settings, SystemUI 等）
│   ├── build/.../handheld_system_ext.mk      # 手持设备扩展
│   └── build/.../aosp_product.mk             # AOSP 产品定义
└── goldfish/product/base_phone.mk
    ├── build/.../telephony_system_ext.mk      # 电话功能扩展
    ├── goldfish/product/generic.mk            # goldfish 通用包
    │   └── (音频、相机、传感器等 HAL 包)
    └── goldfish/product/phone_overlays.mk     # 手机资源叠加
```

这条链路最终带来：
- **系统应用**：Settings、SystemUI、Launcher、Camera2 等
- **电话栈**：Dialer、Contacts、Telephony、SIM 卡管理
- **模拟器 HAL**：GoldfishAudio、GoldfishCamera、GoldfishSensor 等
- **连接**：WiFi、蓝牙模拟
- **资源叠加**：模拟器专用的 UI 调整

### 6. 产品品牌定义

```makefile
PRODUCT_BRAND := Matrix
PRODUCT_NAME := matrix_arm64
PRODUCT_DEVICE := matrix_arm64
PRODUCT_MODEL := Matrix Phone arm64
PRODUCT_MANUFACTURER := Matrix
```

这五个变量定义了设备在系统各处的显示名称：

| 变量 | 值 | 在哪里看到 |
|------|-----|-----------|
| `PRODUCT_BRAND` | Matrix | 设置 → 关于手机 → 品牌名称 |
| `PRODUCT_NAME` | matrix_arm64 | 构建系统内部使用（lunch 名、输出目录） |
| `PRODUCT_DEVICE` | matrix_arm64 | 决定 overlay 和资源查找路径 |
| `PRODUCT_MODEL` | Matrix Phone arm64 | 设置 → 关于手机 → 型号 |
| `PRODUCT_MANUFACTURER` | Matrix | 设置 → 关于手机 → 制造商 |

系统属性中的体现：

```bash
adb shell getprop | grep product
# ro.product.brand=Matrix
# ro.product.name=matrix_arm64
# ro.product.device=matrix_arm64
# ro.product.model=Matrix Phone arm64
# ro.product.manufacturer=Matrix
```

**注意书写顺序**：品牌变量写在 `inherit-product` 之后。这是因为 `inherit-product` 可能会设置默认的品牌值，写在后面可以确保我们的值覆盖继承来的值。`inherit-product` 的去重机制会保留后出现的值。

## inherit-product 的执行机制

`inherit-product` 并不是简单的文件包含，它有一套完整的产品继承机制：

1. **去重**：同一个变量（如 `PRODUCT_COPY_FILES`）在多处 `inherit-product` 时，Soong 会自动合并并去重
2. **顺序保证**：后定义的值可以覆盖先定义的值（对于单值变量）
3. **延迟求值**：产品配置在所有 `inherit-product` 解析完后才统一应用

这也是为什么 matrix 可以在 goldfish 的基础上覆盖品牌信息——我们的值出现在最后，所以优先级最高。

可以用以下命令验证最终的产品配置：

```bash
# 查看完整的产品继承链
make inherit-dump
# 或
m dump-product-matrix_arm64
```

## 编译产物的完整性

`product/matrix_arm64.mk` 通过 `inherit-product` 最终生成的系统包含：

```
out/target/product/matrix_arm64/
├── system.img            # 系统分区镜像
├── vendor.img            # 厂商分区镜像
├── product.img           # 产品分区镜像
├── system_ext.img        # 系统扩展镜像
├── system_dlkm.img       # 系统内核模块镜像
├── super.img             # 动态分区总镜像
├── boot.img              # 内核 + ramdisk
├── vendor_boot.img       # vendor ramdisk
├── userdata.img          # 用户数据分区
├── ramdisk.img           # 根 ramdisk
├── kernel-ranchu         # 模拟器内核
├── advancedFeatures.ini  # 模拟器特性配置
└── ...
```

这些镜像文件全部由构建系统根据 BoardConfig 和 Product 配置自动生成，不需要手动创建。

## 小结

- Product 配置定义软件产品的属性：品牌、应用、分区大小
- `inherit-product` 是 Soong 的产品继承机制，支持自动去重和覆盖
- matrix 通过三层继承获得完整功能：`core_64_bit_only` → `details.mk` → `goldfish/phone.mk`
- 品牌变量写在继承语句之后，确保覆盖 goldfish 的默认值
- 动态分区大小在 Product 配置中定义（ARM64: 1536MB, x86_64: 1792MB）

## 下一步

[05 - 多架构支持](05-multi-arch.md)：对比 ARM64 和 x86_64 的差异，理解公共配置的抽取策略。
