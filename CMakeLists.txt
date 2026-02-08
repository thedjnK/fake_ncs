#
# Copyright (c) 2018 Nordic Semiconductor
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

# Point to NCS root directory.
set(NRF_DIR ${CMAKE_CURRENT_LIST_DIR} CACHE PATH "NCS root directory")

zephyr_include_directories(include)

add_subdirectory(lib)
add_subdirectory(subsys)
add_subdirectory(drivers)

add_subdirectory(${ZEPHYR_NRFXLIB_MODULE_DIR} nrfxlib)
