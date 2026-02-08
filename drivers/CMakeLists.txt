#
# Copyright (c) 2018-2020 Nordic Semiconductor ASA
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

add_subdirectory(entropy)
add_subdirectory_ifdef(CONFIG_PSA_NEED_CRACEN_KMU_DRIVER kmu)
if(NOT CONFIG_MPSL_FEM_ONLY)
  add_subdirectory(mpsl)
endif()
add_subdirectory_ifdef(CONFIG_REGULATOR regulator)
