#
# Copyright (c) 2023 Nordic Semiconductor
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

# Usage:
#   configure_cache(IMAGE <name>)
#
# This function is similar in nature to configure file, except that it takes
# an image as argument to work on the CMakeCache of said image.
#
# The CMake cache of the image will only be re-written in case there are
# variables which has been updated as part of the call.
#
# Only variable of the form `@VAR_NAME@` will be updated.
#
# IMAGE: image name identifying the cache to update.
#
function(configure_cache)
  set(single_args IMAGE)
  cmake_parse_arguments(CONFIGURE_CACHE "" "${single_args}" "" ${ARGN})

  zephyr_check_arguments_required(configure_cache CONFIGURE_CACHE IMAGE)

  ExternalProject_Get_Property(${CONFIGURE_CACHE_IMAGE} BINARY_DIR)

  # Copy the cache file to avoid a dependency to the image's cache file.
  # A dependency on the image's cache file cause unneccessary CMake re-runs for
  # all sysbuild images whenever a setting in the cache changes, even for not
  # sysbuild relevant changes.
  zephyr_file_copy("${BINARY_DIR}/CMakeCache.txt" "${BINARY_DIR}/CMakeCache.tmp" ONLY_IF_DIFFERENT)
  configure_file("${BINARY_DIR}/CMakeCache.tmp" "${BINARY_DIR}/CMakeCache.txt.tmp" @ONLY)
  zephyr_file_copy("${BINARY_DIR}/CMakeCache.txt.tmp" "${BINARY_DIR}/CMakeCache.txt" ONLY_IF_DIFFERENT)
endfunction()

function(store_ncs_vars)
  get_property(ncs_vars DIRECTORY ${SYSBUILD_CURRENT_CMAKE_DIR} PROPERTY VARIABLES)
  list(FILTER ncs_vars INCLUDE REGEX "NCS_.*")
  foreach(var ${ncs_vars})
    set_property(GLOBAL APPEND PROPERTY NCS_VARS ${var})
    set_property(GLOBAL PROPERTY ${var} ${${var}})
  endforeach()
endfunction()

function(restore_ncs_vars)
  get_property(ncs_vars GLOBAL PROPERTY NCS_VARS)
  foreach(var ${ncs_vars})
    get_property(var_value GLOBAL PROPERTY ${var})
    set(${var} ${var_value} PARENT_SCOPE)
  endforeach()
endfunction()

function(${SYSBUILD_CURRENT_MODULE_NAME}_pre_cmake)
  cmake_parse_arguments(PRE_CMAKE "" "" "IMAGES" ${ARGN})
  restore_ncs_vars()
  UpdateableImage_Get(updateable_images ALL)

  foreach(image ${PRE_CMAKE_IMAGES})
    if(SB_CONFIG_BUILD_OUTPUT_BIN)
      set_config_bool(${image} CONFIG_BUILD_OUTPUT_BIN y)
    else()
      set_config_bool(${image} CONFIG_BUILD_OUTPUT_BIN n)
    endif()

    if(SB_CONFIG_BUILD_OUTPUT_HEX)
      set_config_bool(${image} CONFIG_BUILD_OUTPUT_HEX y)
    else()
      set_config_bool(${image} CONFIG_BUILD_OUTPUT_HEX n)
    endif()
  endforeach()

  if(SB_CONFIG_BOOTLOADER_MCUBOOT)
    if(SB_CONFIG_BOOT_SIGNATURE_TYPE_PURE)
      set_config_bool(mcuboot CONFIG_BOOT_SIGNATURE_TYPE_PURE y)
    endif()

    if(SB_CONFIG_BOOT_IMG_HASH_ALG_SHA512 AND NOT (SB_CONFIG_MCUBOOT_SIGNATURE_USING_KMU AND SB_CONFIG_BOOT_SIGNATURE_TYPE_PURE))
      set_config_bool(mcuboot CONFIG_BOOT_IMG_HASH_ALG_SHA512 y)
    endif()

    # Apply configuration to application
    foreach(image ${updateable_images})
      foreach(mode ${application_mcuboot_modes})
        if("${mode}" IN_LIST application_mcuboot_mode)
          set_config_bool(${image} ${mode} y)
        else()
          set_config_bool(${image} ${mode} n)
        endif()
      endforeach()

      if(SB_CONFIG_BOOT_SIGNATURE_TYPE_ED25519)
        set_config_bool(${image} CONFIG_MCUBOOT_BOOTLOADER_SIGNATURE_TYPE_ED25519 y)
      endif()

      if(SB_CONFIG_BOOT_SIGNATURE_TYPE_PURE)
        set_config_bool(${image} CONFIG_MCUBOOT_BOOTLOADER_SIGNATURE_TYPE_PURE y)
      endif()

      if(SB_CONFIG_BOOT_IMG_HASH_ALG_SHA512)
        set_config_bool(${image} CONFIG_MCUBOOT_BOOTLOADER_USES_SHA512 y)
      endif()

      set(${image}_SIGNING_SCRIPT "${ZEPHYR_NRF_MODULE_DIR}/cmake/sysbuild/image_signing.cmake" CACHE INTERNAL "MCUboot signing script" FORCE)
    endforeach()

    # The NRF54LX goes with PSA crypto by default
    if(SB_CONFIG_SOC_SERIES_NRF54L)
      if(SB_CONFIG_BOOT_SIGNATURE_TYPE_NONE)
        set_config_bool(mcuboot CONFIG_NRF_SECURITY y)
      elseif(SB_CONFIG_BOOT_SIGNATURE_TYPE_ED25519)
        set_config_bool(mcuboot CONFIG_NRF_SECURITY y)

        # We are sure that ED25519 signature on MCUboot does not need these
        set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_AEAD_DRIVER n)
        set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_PAKE_DRIVER n)
        if(SB_CONFIG_BOOT_ENCRYPTION)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_CIPHER_DRIVER y)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_MAC_DRIVER y)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_KEY_AGREEMENT_DRIVER y)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_KEY_DERIVATION_DRIVER y)
        else()
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_CIPHER_DRIVER n)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_MAC_DRIVER n)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_KEY_AGREEMENT_DRIVER n)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_KEY_DERIVATION_DRIVER n)
        endif()

        if(SB_CONFIG_MCUBOOT_SIGNATURE_USING_KMU)
          set_config_bool(mcuboot CONFIG_BOOT_SIGNATURE_USING_KMU y)

          if(SB_CONFIG_MCUBOOT_SIGNATURE_KMU_UROT_MAPPING)
            set_config_bool(mcuboot CONFIG_NCS_BOOT_SIGNATURE_KMU_UROT_MAPPING y)
          else()
            set_config_bool(mcuboot CONFIG_NCS_BOOT_SIGNATURE_KMU_UROT_MAPPING n)
          endif()
        else()
          set_config_bool(mcuboot CONFIG_BOOT_SIGNATURE_USING_KMU n)
        endif()

        # MCUboot uses hash function to identify key internally when KMU is disabled.
        if(SB_CONFIG_MCUBOOT_SIGNATURE_USING_KMU AND SB_CONFIG_BOOT_SIGNATURE_TYPE_PURE)
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_HASH_DRIVER n)
        else()
          set_config_bool(mcuboot CONFIG_PSA_USE_CRACEN_HASH_DRIVER y)
        endif()
      endif()
    endif()
  endif()

  if(SB_CONFIG_APPROTECT_USE_UICR OR SB_CONFIG_APPROTECT_LOCK OR SB_CONFIG_APPROTECT_USER_HANDLING OR SB_CONFIG_APPROTECT_DISABLE OR
     SB_CONFIG_SECURE_APPROTECT_USE_UICR OR SB_CONFIG_SECURE_APPROTECT_LOCK OR SB_CONFIG_SECURE_APPROTECT_USER_HANDLING OR SB_CONFIG_SECURE_APPROTECT_DISABLE)
    # Apply APPROTECT configuration to target images
    if(SB_CONFIG_APPROTECT_USE_UICR)
      set(normal_approtect CONFIG_NRF_APPROTECT_USE_UICR)
    elseif(SB_CONFIG_APPROTECT_LOCK)
      set(normal_approtect CONFIG_NRF_APPROTECT_LOCK)
    elseif(SB_CONFIG_APPROTECT_USER_HANDLING)
      set(normal_approtect CONFIG_NRF_APPROTECT_USER_HANDLING)
    elseif(SB_CONFIG_APPROTECT_DISABLE)
      set(normal_approtect CONFIG_NRF_APPROTECT_DISABLE)
    endif()

    if(SB_CONFIG_SECURE_APPROTECT_USE_UICR)
      set(secure_approtect CONFIG_NRF_SECURE_APPROTECT_USE_UICR)
    elseif(SB_CONFIG_SECURE_APPROTECT_LOCK)
      set(secure_approtect CONFIG_NRF_SECURE_APPROTECT_LOCK)
    elseif(SB_CONFIG_SECURE_APPROTECT_USER_HANDLING)
      set(secure_approtect CONFIG_NRF_SECURE_APPROTECT_USER_HANDLING)
    elseif(SB_CONFIG_SECURE_APPROTECT_DISABLE)
      set(secure_approtect CONFIG_NRF_SECURE_APPROTECT_DISABLE)
    endif()

    foreach(image ${IMAGES})
      # Application (or other) core image
      if(normal_approtect)
        set_config_bool(${image} ${normal_approtect} y)
      endif()
      if(secure_approtect)
        set_config_bool(${image} ${secure_approtect} y)
      endif()
    endforeach()

    set(normal_approtect)
    set(secure_approtect)
    set(network_images)
  endif()

  if(SB_CONFIG_CRACEN_MICROCODE_LOAD_ONCE)
    if(SB_CONFIG_CRACEN_MICROCODE_LOAD_MCUBOOT)
      set_config_bool(mcuboot CONFIG_CRACEN_LOAD_MICROCODE y)
    endif()

    set_config_bool(${DEFAULT_IMAGE} CONFIG_CRACEN_LOAD_MICROCODE n)
  endif()
endfunction(${SYSBUILD_CURRENT_MODULE_NAME}_pre_cmake)

# Sysbuild function hooks used by nRF Connect SDK
function(${SYSBUILD_CURRENT_MODULE_NAME}_post_cmake)
  cmake_parse_arguments(POST_CMAKE "" "" "IMAGES" ${ARGN})
  restore_ncs_vars()

  set(SYSBUILD y)

  set_property(GLOBAL PROPERTY DOMAIN_APP_APP ${DEFAULT_IMAGE})

  # Include any files that need to merge files with uicr_merged.hex
  if(SB_CONFIG_BT_FAST_PAIR_PROV_DATA AND NOT SB_CONFIG_PARTITION_MANAGER)
    # The DTS partition for the Fast Pair hex file is available in the post-CMake stage.
    include(${ZEPHYR_NRF_MODULE_DIR}/cmake/sysbuild/fast_pair/hex.cmake)
  endif()

  if(SB_CONFIG_SECURE_BOOT_GENERATE_DEFAULT_KMU_KEYFILE OR SB_CONFIG_MCUBOOT_GENERATE_DEFAULT_KMU_KEYFILE)
    include(${ZEPHYR_NRF_MODULE_DIR}/cmake/sysbuild/generate_default_keyfile.cmake)
  endif()

  if(SB_CONFIG_SECURE_BOOT_BOOTCONF_LOCK_WRITES)
    include(${ZEPHYR_NRF_MODULE_DIR}/cmake/sysbuild/bootconf.cmake)
  endif()

  include(${ZEPHYR_NRF_MODULE_DIR}/cmake/extensions.cmake)

  foreach(image ${IMAGES})
    configure_cache(IMAGE ${image})
  endforeach()

  # Add a dependency on the main image's .config file to ensure Kconfig values that have been read
  # and used to generate tasks are not stale, add similar dependencies on other images which have
  # configuration that is read if required options are enabled
#  ExternalProject_Get_Property(${DEFAULT_IMAGE} BINARY_DIR)
#  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${BINARY_DIR}/zephyr/.config)
endfunction(${SYSBUILD_CURRENT_MODULE_NAME}_post_cmake)

# Enable use of partition manager with sysbuild.
# Consider if this shoulc come through Sysbuild Kconfig flag.
set(NCS_SYSBUILD_PARTITION_MANAGER TRUE)

list(APPEND CMAKE_MODULE_PATH ${ZEPHYR_NRF_MODULE_DIR}/cmake/sysbuild/modules)
include(ncs_sysbuild_extensions)

store_ncs_vars()
