# 02 - 创建最小可运行设备

## 构建系统如何发现设备

当你执行 `source build/envsetup.sh` 时，构建系统会扫描源码树中所有包含 `AndroidProducts.mk` 文件的目录。这个文件是 **设备被发现和注册的入口**。

扫描路径包括：
- `device/<vendor>/<product>/AndroidProducts.mk`
- `vendor/<vendor>/<product>/AndroidProducts.mk`

只要你的目录下有这个文件，构建系统就能找到你的设备。

## AndroidProducts.mk 详解

这是 matrix 的 `AndroidProducts.mk` 完整内容：

```makefile
# device/matrix/AndroidProducts.mk

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/product/matrix_arm64.mk \
    $(LOCAL_DIR)/product/matrix_x86_64.mk

COMMON_LUNCH_CHOICES := \
    matrix_arm64-trunk_staging-userdebug \
    matrix_arm64-trunk_staging-eng \
    matrix_x86_64-trunk_staging-userdebug \
    matrix_x86_64-trunk_staging-eng
```

### PRODUCT_MAKEFILES

`PRODUCT_MAKEFILES` 告诉构建系统：这个目录下有哪些产品定义文件。每个 `.mk` 文件定义一个产品。

- `$(LOCAL_DIR)` 是一个内置变量，指向当前 `AndroidProducts.mk` 所在目录，即 `device/matrix`
- 所以实际路径是 `device/matrix/product/matrix_arm64.mk` 和 `device/matrix/product/matrix_x86_64.mk`
- 我们注册了两个产品：ARM64 和 x86_64 各一个

### COMMON_LUNCH_CHOICES

`COMMON_LUNCH_CHOICES` 定义用户在 `lunch` 菜单中看到的选项。格式为：

```
<产品名>-<分支>-<构建类型>
```

| 字段 | 含义 | 示例值 |
|------|------|--------|
| 产品名 | 对应 `PRODUCT_MAKEFILES` 中的产品 | `matrix_arm64` |
| 分支 | Android 版本分支 | `trunk_staging`（AOSP 16 开发分支） |
| 构建类型 | 编译优化级别和调试能力 | `userdebug` / `eng` |

**userdebug** vs **eng**：

| | userdebug | eng |
|---|-----------|-----|
| 用于 | 日常开发调试 | 系统级开发 |
| adb root | 默认可用 | 默认可用 |
| 调试包 | 包含 | 包含更多 |
| 性能 | 接近 user | 较低（额外检测） |
| ProGuard | 启用 | 禁用 |

对于学习 AOSP，推荐使用 `eng` 构建类型，因为它包含更多的调试工具和符号信息。

### 没有 user 类型

注意 `COMMON_LUNCH_CHOICES` 中没有 `user` 类型。这是因为 `user` 构建用于正式发布，开发阶段通常不需要。如果需要，添加一行 `matrix_arm64-trunk_staging-user` 即可。

## vendorsetup.sh 的演变

```makefile
# device/matrix/vendorsetup.sh

# Lunch combinations are now defined via COMMON_LUNCH_CHOICES
# in AndroidProducts.mk (AOSP 15+ style).
```

在 AOSP 14 及之前，`vendorsetup.sh` 是注册 lunch 组合的地方，内容类似：

```bash
# 旧写法（AOSP 14 及之前）
add_lunch_combo matrix_arm64-userdebug
add_lunch_combo matrix_arm64-eng
```

从 AOSP 15 开始，lunch 组合统一在 `AndroidProducts.mk` 的 `COMMON_LUNCH_CHOICES` 中声明。`vendorsetup.sh` 保留但内容简化为注释，确保向后兼容。

这是一个重要的历史演变：
- **AOSP 14 及之前**：`vendorsetup.sh` + `add_lunch_combo`
- **AOSP 15+**：`AndroidProducts.mk` + `COMMON_LUNCH_CHOICES`

如果你的项目需要兼容旧版本 AOSP，可以在 `vendorsetup.sh` 中同时保留两种写法。

## 实操：注册并编译你的设备

### 步骤 1：初始化构建环境

```bash
cd <AOSP_ROOT>
source build/envsetup.sh
```

这一步会扫描所有 `AndroidProducts.mk`，将 matrix 设备注册到构建系统中。

### 步骤 2：选择产品

```bash
lunch
```

你会看到菜单中出现 matrix 的选项：

```
...
37. matrix_arm64-trunk_staging-eng
38. matrix_arm64-trunk_staging-userdebug
39. matrix_x86_64-trunk_staging-eng
40. matrix_x86_64-trunk_staging-userdebug
...
```

也可以直接指定：

```bash
lunch matrix_arm64-trunk_staging-eng
```

### 步骤 3：编译

```bash
m -j$(nproc)
```

首次编译时间取决于机器配置，通常需要 30 分钟到数小时。后续增量编译会快很多。

### 步骤 4：运行模拟器

```bash
emulator
```

如果一切正常，你会看到一个完整的 Android 系统在模拟器中启动，"关于手机" 中显示 "Matrix Phone"。

## 验证清单

编译完成后，可以通过以下方式验证：

```bash
# 查看编译出的产品名称
echo $TARGET_PRODUCT
# 输出: matrix_arm64

# 查看构建类型
echo $TARGET_BUILD_TYPE
# 输出: eng

# 查看输出目录
ls out/target/product/matrix_arm64/
# 应该能看到 system.img, vendor.img, boot.img 等
```

## 文件之间的关系

```
AndroidProducts.mk ─── 注册 ──→ product/matrix_arm64.mk
       │                              │
       │ 定义 lunch 组合               │ inherit-product
       │                              │
       ▼                              ▼
  lunch 菜单              board/matrix_arm64/details.mk
                                  │
                                  │ include
                                  ▼
                         goldfish/kernel/arm64.mk
                         goldfish/BoardConfigCommon.mk
                         goldfish/product/phone.mk
```

`AndroidProducts.mk` 是入口，它指向 `product/*.mk`，后者再通过 `inherit-product` 拉起整个 goldfish 技术栈。

## 小结

- `AndroidProducts.mk` 是构建系统发现设备的入口，通过 `PRODUCT_MAKEFILES` 注册产品、`COMMON_LUNCH_CHOICES` 定义 lunch 选项
- AOSP 15+ 将 lunch 组合从 `vendorsetup.sh` 迁移到了 `AndroidProducts.mk`
- 编译和运行只需三步：`source envsetup.sh` → `lunch` → `m` → `emulator`

## 下一步

[03 - Board 配置详解](03-board-config.md)：详解硬件架构定义、分区布局和 BoardConfig 继承链。
