#
# Copyright (c) 2024 Nordic Semiconductor ASA
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

if(CONFIG_MPSL)
  add_subdirectory(init)
endif()

add_subdirectory(cx)

if(CONFIG_MPSL OR CONFIG_MPSL_FEM_ONLY)
  add_subdirectory(hwres)
endif()

if(CONFIG_MPSL_USE_ZEPHYR_PM)
  add_subdirectory(pm)
endif()

if(CONFIG_MPSL_USE_EXTERNAL_CLOCK_CONTROL)
  add_subdirectory(clock_ctrl)
endif()
