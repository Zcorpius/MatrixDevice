# 定制自己的 Android 设备 —— device/matrix 专栏

从零开始，在 AOSP 16 中创建一个自定义设备配置，逐步掌握 Android 构建系统的设备定制能力。

## 专栏定位

以 `device/matrix` 项目为主线，从最小可运行设备出发，渐进式添加系统属性、资源叠加、init 脚本、SEPolicy、预装应用等定制能力。每篇文章对应一个独立主题，包含概念讲解、代码实现和编译验证。

## 第一部分：基础搭建

以当前 `device/matrix` 已有代码为基础，讲透 AOSP 设备配置的核心概念和继承机制。

| 章节 | 标题 | 内容 | 涉及文件 |
|------|------|------|----------|
| 01 | AOSP 设备定制全景 | 为什么需要自定义 device、AOSP 设备目录的作用、goldfish 与模拟器的关系 | 概念介绍 |
| 02 | 创建最小可运行设备 | `AndroidProducts.mk` 产品注册、`COMMON_LUNCH_CHOICES` 午餐组合、lunch 编译与模拟器运行 | `AndroidProducts.mk`, `vendorsetup.sh` |
| 03 | Board 配置详解 | 架构定义(arm64/x86_64)、分区大小、动态分区(super.img)、BoardConfig 继承链 | `board/BoardConfigCommon.mk`, `board/matrix_arm64/BoardConfig.mk`, `details.mk` |
| 04 | Product 配置详解 | 产品品牌属性、继承 `core_64_bit_only` 与 `goldfish/phone.mk`、编译出完整系统镜像的来龙去脉 | `product/matrix_arm64.mk` |
| 05 | 多架构支持 | ARM64 与 x86_64 的差异点、如何用公共配置消除重复 | `board/matrix_x86_64/`, `product/matrix_x86_64.mk` |

## 第二部分：定制能力扩展

在基础设备上逐步添加各项定制能力，每篇文章对应一次代码提交。

| 章节 | 标题 | 内容 | 新增内容 |
|------|------|------|----------|
| 06 | 系统属性定制 | `*.prop` 文件的加载顺序、build fingerprint、自定义系统属性 | `product/*.prop` |
| 07 | 资源叠加(Overlay) | Runtime Resource Overlay 机制、替换默认壁纸/图标/字符串 | `overlay/` 目录 |
| 08 | 自定义 init 脚本 | `init.matrix.rc` 编写、开机服务管理、属性触发动作 | `init/` 目录 |
| 09 | SEPolicy 定制 | SELinux 策略基础、为自定义服务添加域、te 文件编写 | `sepolicy/` 目录 |
| 10 | 预装应用 | 预装第三方 APK、构建自有 App 集成到系统镜像 | `product/*.mk` 中添加 |
| 11 | 权限与特性声明 | `handheld_core_hardware.xml` 等特性声明文件、设备能力声明 | 权限 XML 文件 |

## 第三部分：进阶主题

从模拟器走向更完整的设备定制。

| 章节 | 标题 | 内容 |
|------|------|------|
| 12 | Vendor 分区与 HAL 定制 | 添加自定义 HAL 模块、理解 vendor image 的构成 |
| 13 | 从模拟器到真机 | 剥离 goldfish 依赖、替换真实 kernel/dtb/grub |
| 14 | OTA 升级与签名 | AB/Non-AB 升级流程、自定义签名密钥 |
| 15 | 完整设备树回顾 | 回顾整个 device 目录的最终结构、设计原则与最佳实践 |

## 写作规范

### 文章结构

每篇文章遵循统一结构：

1. **概念讲解** — 这个配置在 AOSP 构建系统中的作用和原理
2. **代码实现** — `device/matrix` 中对应的完整代码，逐行解释
3. **继承链分析** — 用 `make inherit-dump` 或源码追踪，展示配置的完整继承路径
4. **编译验证** — 编译命令、运行效果、验证方法
5. **Diff 总结** — 本篇文章对应的完整代码变更，方便读者对照

### 代码风格

- 每篇文章对应一个独立的 git commit
- 不引入超出主题范围的改动
- 保持与 AOSP 源码一致的注释风格
- 所有代码都经过编译验证

### 当前进度

- [x] 第一部分：基础搭建（代码已完成，待撰写文章）
- [ ] 第二部分：定制能力扩展（代码与文章均待完成）
- [ ] 第三部分：进阶主题（代码与文章均待完成）
