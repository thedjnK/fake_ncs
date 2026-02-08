#
# Copyright (c) 2019-2022 Nordic Semiconductor
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

# This file is nrf_security's entry-point for the NCS build system
# Set SPM to false as we are not in a secure image build
set(CONFIG_MBEDTLS_PSA_CRYPTO_SPM False)

# Include generic macros
include(cmake/extensions.cmake)

set(mbedcrypto_target mbedcrypto)

# Generate the file containing all static paths and configurations used both in
# TF-M and non TF-M builds
configure_file(${CMAKE_CURRENT_LIST_DIR}/configs/config_extra.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/cmake/config_extra.cmake
)

# Include files with standard paths like oberon-psa-core and nrf_security root
include(${CMAKE_CURRENT_BINARY_DIR}/cmake/config_extra.cmake)

if(CONFIG_SSF_SERVER_PSA_CRYPTO_SERVICE_ENABLED)
  # Inside the SSF server, when the PSA crypto service is enabled we need to
  # use the OWNER id to give key ownership to the differrent domains.
  set(CONFIG_MBEDTLS_PSA_CRYPTO_KEY_ID_ENCODES_OWNER     True)
else()
  # MBEDTLS_PSA_CRYPTO_KEY_ID_ENCODES_OWNER must be disabled for Zephyr
  # builds or when MBEDTLS_USE_PSA_CRYPTO is enabled (e.g. for TLS/DTLS
  # and x.509 support) Note: This configuration is internal and may be
  # removed with a new mbed TLS version
  set(CONFIG_MBEDTLS_PSA_CRYPTO_KEY_ID_ENCODES_OWNER     False)
endif()

if(CONFIG_BUILD_WITH_TFM)
  # Execute Cmake logic to forward configurations to TF-M build
  include(${NRF_SECURITY_ROOT}/cmake/config_to_tf-m.cmake)
endif()

  nrf_security_debug("Building for pure Zephyr")

set(CONFIG_MBEDTLS_PSA_CRYPTO_EXTERNAL_RNG  True)

# Add library for crypto configs (NS/S-only build)
# The name and intent of this comes from TF-M distribution
add_library(psa_crypto_config INTERFACE)

# Add config files required for PSA crypto interface
target_compile_definitions(psa_crypto_config
  INTERFACE
    -DMBEDTLS_CONFIG_FILE="${CONFIG_MBEDTLS_CFG_FILE}"
    -DMBEDTLS_PSA_CRYPTO_CONFIG_FILE="${CONFIG_MBEDTLS_PSA_CRYPTO_CONFIG_FILE}"
)

# Add library for crypto configs (S-only or Secure image build)
# The name and intent of this comes from TF-M distribution
add_library(psa_crypto_library_config INTERFACE)

# Add config files required for PSA core
target_compile_definitions(psa_crypto_library_config
  INTERFACE
    -DMBEDTLS_CONFIG_FILE="${CONFIG_MBEDTLS_CFG_FILE}"
    -DMBEDTLS_PSA_CRYPTO_CONFIG_FILE="${CONFIG_MBEDTLS_PSA_CRYPTO_CONFIG_FILE}"
    -DMBEDTLS_PSA_CRYPTO_USER_CONFIG_FILE="${CONFIG_MBEDTLS_PSA_CRYPTO_USER_CONFIG_FILE}"
)

# Add a library for crypto includes for the PSA interface (NS, S-only and TF-M)
# The name and intent of this comes from TF-M distribution
add_library(psa_interface INTERFACE)

# Add the includes from nrf_security, Oberon PSA core, and Arm Mbed TLS
# to the psa_interface library
target_include_directories(psa_interface
  INTERFACE
    # Oberon PSA headers
    ${OBERON_PSA_CORE_PATH}/include
    ${OBERON_PSA_CORE_PATH}/library
    # Mbed TLS (mbedcrypto) PSA headers
    ${ARM_MBEDTLS_PATH}/library
    ${ARM_MBEDTLS_PATH}/include
    ${ARM_MBEDTLS_PATH}/include/library
)

# Finally adding the crypto lib
add_subdirectory(${NRFXLIB_DIR}/crypto crypto_copy)

# Add mbed TLS Libraries
add_subdirectory(src)
