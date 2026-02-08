#
# Copyright (c) 2018 Nordic Semiconductor
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

zephyr_sources_ifdef(CONFIG_BT_LL_SOFTDEVICE_HEADERS_INCLUDE hci_vs_sdc.c)

add_subdirectory_ifdef(CONFIG_BT_LL_SOFTDEVICE controller)

add_subdirectory(host_extensions)
