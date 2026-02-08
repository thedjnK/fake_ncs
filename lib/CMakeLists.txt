#
# Copyright (c) 2018 Nordic Semiconductor ASA
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

add_subdirectory_ifdef(CONFIG_MULTITHREADING_LOCK multithreading_lock)
add_subdirectory_ifdef(CONFIG_HW_UNIQUE_KEY_SRC hw_unique_key)
add_subdirectory_ifdef(CONFIG_IDENTITY_KEY identity_key)
