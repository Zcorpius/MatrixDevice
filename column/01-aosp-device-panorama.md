# 01 - AOSP 设备定制全景

## 为什么需要自定义 device

当你下载完 AOSP 源码，执行 `lunch` 时会看到一长串产品列表：

```
aosp_arm64-trunk_staging-userdebug
aosp_x86_64-trunk_staging-userdebug
sdk_phone_arm64-trunk_staging-userdebug
...
```

这些产品都定义在 `device/` 目录下。AOSP 构建系统的核心设计原则是 **产品与平台分离**：`build/` 和 `frameworks/` 定义 Android 平台的能力，而 `device/` 决定这些能力如何组合到一台具体设备上。

对于手机厂商，`device/` 是适配新硬件的核心入口；对于学习 AOSP 的开发者，`device/` 是理解构建系统最直接的切入点。

## device 目录的结构与职责

在 AOSP 源码树中，`device/` 目录按厂商和设备组织：

```
device/
├── generic/
│   ├── goldfish/        # 模拟器参考设备（我们的基座）
│   └── common/          # 通用硬件配置
├── google/              # Pixel 设备
├── samsung/             # 三星设备（如果有的话）
└── matrix/              # 我们的自定义设备
```

一个典型的 device 目录需要回答以下问题：

| 问题 | 由哪个文件回答 |
|------|---------------|
| 有哪些产品可以编译？ | `AndroidProducts.mk` |
| 使用什么 CPU 架构？ | `BoardConfig.mk` |
| 分区怎么划分？ | `BoardConfig.mk` |
| 预装哪些应用？ | `product/*.mk` |
| 系统叫什么名字？ | `product/*.mk` 中的品牌变量 |
| 用什么内核？ | `BoardConfig.mk` 或 `details.mk` |
| 开机启动什么服务？ | `init/*.rc` |
| 安全策略怎么配？ | `sepolicy/` |

## goldfish 是什么

`device/generic/goldfish` 是 AOSP 官方维护的 **模拟器参考设备**。"goldfish" 这个名字来自 Android 模拟器使用的虚拟硬件平台代号。

goldfish 提供了一个完整的、可以在 Android Emulator 中运行的 Android 手机系统，包含：

- **内核**：预编译的 Linux 6.12 内核镜像
- **HAL 层**：音频、相机、传感器、GPU 等虚拟硬件的 HAL 实现
- **电话栈**：完整的 telephony 支持（模拟的 RIL）
- **连接**：WiFi、蓝牙的模拟实现
- **显示**：OpenGL ES / Vulkan 软件渲染
- **分区方案**：动态分区（super.img）布局
- **SEPolicy**：模拟器环境的安全策略

一句话总结：**goldfish 让你不碰任何硬件就能编译运行一个完整的 Android 系统**。

## 模拟器 vs 真机

| 维度 | 模拟器 (goldfish) | 真机 (如 Pixel) |
|------|-------------------|----------------|
| 内核 | 预编译虚拟内核 | 需要编译或提供专有内核 |
| HAL | 虚拟 HAL（goldfish HAL） | 厂商 HAL（vendor image） |
| GPU | 软件渲染 / 宿主机 GPU | 真实 GPU 驱动 |
| 存储 | 文件模拟的分区 | 真实 flash 分区 |
| 调试 | 直接 adb / logcat | 可能需要额外工具 |
| 迭代速度 | 快（几分钟） | 慢（刷机流程） |

本专栏全程使用模拟器方案。以 goldfish 为基座定制自己的设备，可以在不依赖任何硬件的情况下完整学习 AOSP 设备定制流程。

## device/matrix 的设计思路

`device/matrix` 的设计原则是 **最小可运行**：

1. **完全继承 goldfish**，不重新实现任何已有功能
2. **只覆盖品牌信息**，让系统显示自己的名字
3. **支持双架构**（arm64 和 x86_64），展示架构间的差异管理
4. **代码量最小**，整个 device 目录不到 10 个文件

最终效果：编译后能在 Android Emulator 中运行一个名为 "Matrix Phone" 的完整 Android 系统。

### 目录结构总览

```
device/matrix/
├── AndroidProducts.mk              # 产品注册入口
├── vendorsetup.sh                  # 兼容脚本（AOSP 15+ 已简化）
├── board/                          # 硬件/板级配置
│   ├── BoardConfigCommon.mk        # 公共 Board 配置
│   ├── matrix_arm64/               # ARM64 架构配置
│   │   ├── BoardConfig.mk
│   │   └── details.mk
│   └── matrix_x86_64/              # x86_64 架构配置
│       ├── BoardConfig.mk
│       └── details.mk
└── product/                        # 产品定义
    ├── matrix_arm64.mk
    └── matrix_x86_64.mk
```

这个结构遵循 AOSP 的约定：
- **board/** 管硬件相关（架构、分区、内核）
- **product/** 管软件相关（品牌、应用、属性）
- **AndroidProducts.mk** 是构建系统发现这个设备的入口

## 继承关系全景

```
                          ┌──────────────────────────┐
                          │    build/make (平台)      │
                          │  core_64_bit_only.mk      │
                          │  generic_system.mk        │
                          │  handheld_system_ext.mk   │
                          └──────────┬───────────────┘
                                     │ inherit-product
                          ┌──────────▼───────────────┐
                          │  goldfish (模拟器基座)     │
                          │  phone.mk                 │
                          │  handheld.mk              │
                          │  base_phone.mk            │
                          │  BoardConfigCommon.mk     │
                          │  kernel/arm64.mk          │
                          └──────────┬───────────────┘
                                     │ inherit-product / include
                          ┌──────────▼───────────────┐
                          │  matrix (我们的设备)       │
                          │  product/matrix_arm64.mk  │
                          │  board/matrix_arm64/      │
                          └──────────────────────────┘
```

matrix 只需在 goldfish 的基础上添加少量文件，就能拥有一个完整的 Android 设备定义。

## 小结

- `device/` 是 AOSP 中定义具体设备的目录，控制产品如何组合
- goldfish 是模拟器参考设备，提供完整的虚拟硬件支持
- matrix 以 goldfish 为基座，用最少的文件实现一个可运行的自定义设备
- 接下来的文章将逐一解析 matrix 中的每个文件

## 下一步

[02 - 创建最小可运行设备](02-create-minimal-device.md)：详解 `AndroidProducts.mk` 的产品注册机制。
