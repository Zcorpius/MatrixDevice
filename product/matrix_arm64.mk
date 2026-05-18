#
# Copyright (C) 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Matrix arm64 phone product configuration

PRODUCT_USE_DYNAMIC_PARTITIONS := true

PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed

BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE ?= $(shell expr 1536 \* 1048576 )
BOARD_SUPER_PARTITION_SIZE := $(shell expr $(BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE) + 8388608 )  # +8M

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# Inherit board details (kernel, fstab, etc.)
$(call inherit-product, device/matrix/board/matrix_arm64/details.mk)

# Inherit goldfish phone product (full emulator phone stack)
$(call inherit-product, device/generic/goldfish/product/phone.mk)

# Matrix-specific product branding
PRODUCT_BRAND := Matrix
PRODUCT_NAME := matrix_arm64
PRODUCT_DEVICE := matrix_arm64
PRODUCT_MODEL := Matrix Phone arm64
PRODUCT_MANUFACTURER := Matrix
