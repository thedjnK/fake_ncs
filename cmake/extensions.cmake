#
# Copyright (c) 2020 Nordic Semiconductor
#
# SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
#

#
# Helper macro for verifying that at least one of the required arguments has
# been provided by the caller.
#
# As FATAL_ERROR will be raised if not one of the required arguments has been
# passed by the caller.
#
# Usage:
#   check_arguments_required(<function_name> <prefix> <arg1> [<arg2> ...])
#
macro(check_arguments_required function prefix)
  set(required_found FALSE)
  foreach(required ${ARGN})
    if(DEFINED ${prefix}_${required})
      set(required_found TRUE)
    endif()
  endforeach()

  if(NOT required_found)
    message(FATAL_ERROR "${function}(...) missing a required argument: ${ARGN}")
  endif()
endmacro()

#
# Helper macro for verifying that all the required arguments has # been
# provided by the caller.
#
# As FATAL_ERROR will be raised if one of the required arguments is missing.
#
# Usage:
#   check_arguments_required_all(<function_name> <prefix> <arg1> [<arg2> ...])
#
macro(check_arguments_required_all function prefix)
  foreach(required ${ARGN})
    if(NOT DEFINED ${prefix}_${required})
      message(FATAL_ERROR "${function}(...) missing a required argument: ${required}")
    endif()
  endforeach()
endmacro()

#
# Helper macro for verifying that none of the mutual exclusive arguments are
# provided together with the first argument.
#
# As FATAL_ERROR will be raised if first argument is given together with one
# of the following mutual exclusive arguments.
#
# Usage:
#   check_arguments_exclusive(<function_name> <prefix> <arg1> <exlude-arg1> [<exclude-arg2> ...])
#
macro(check_arguments_exclusive function prefix argument)
  foreach(prohibited ${ARGN})
    if(DEFINED ${prefix}_${argument} AND ${prefix}_${prohibited})
      message(FATAL_ERROR "set_shared(${argument} ...) cannot be used with "
        "argument: ${prohibited}"
      )
    endif()
  endforeach()
endmacro()

#
# Usage
#   set_shared(IMAGE <img> [APPEND] PROPERTY <property> <value>)
#
# Shares a property from child to parent.
# The property is shared through an intermediate shared_vars.cmake file which
# will be parsed by the parent image at CMake configure time.
#
# Example usage 'set_shared(IMAGE child PROPERTY visible_in_parent "I AM YOUR CHILD")'
#
# Usage
#   set_shared(FILE <file>)
#
# Shares all properties in file to parent.
# This function can be used to re-share properties from a child to its
# grand parent.
#
function(set_shared)
  set(flags       "APPEND")
  set(single_args "FILE;IMAGE")
  set(multi_args  "PROPERTY")
  cmake_parse_arguments(SHARE "${flags}" "${single_args}" "${multi_args}" ${ARGN})

  list(POP_FRONT SHARE_PROPERTY listname)
  if(SHARE_APPEND)
    list(APPEND ${listname} ${SHARE_PROPERTY})
    list(REMOVE_DUPLICATES ${listname})
    set(SHARE_PROPERTY ${${listname}})
  endif()
  set(${listname} "${SHARE_PROPERTY}" CACHE INTERNAL "shared var")
endfunction()

# generate_shared(IMAGE <img> FILE <file>)
function(generate_shared)
  set(single_args "IMAGE;FILE")
  cmake_parse_arguments(SHARE "" "${single_args}" "" ${ARGN})

  check_arguments_required_all("generate_shared" SHARE IMAGE FILE)

  set(prop_target ${IMAGE_NAME}_shared_property_target)
  file(GENERATE OUTPUT ${SHARE_FILE}
      CONTENT
        "$<JOIN:$<TARGET_PROPERTY:${prop_target},image_targets>,\n>
$<TARGET_PROPERTY:${prop_target},shared_vars>"
    )
endfunction()

#
# Usage
#   get_shared(<var> IMAGE <img> PROPERTY <property>)
#
# Get a property value defined by an image or domain <img> if it exists.
# The property value will be returned in the variable referenced by <var>.
#
# Example usage 'get_shared(prop_value IMAGE child PROPERTY property_in_child)'
#
function(get_shared var)
  set(single_args "IMAGE")
  set(multi_args  "PROPERTY")
  cmake_parse_arguments(SHARE "" "${single_args}" "${multi_args}" ${ARGN})

  check_arguments_required_all("get_shared" SHARE IMAGE PROPERTY)

  if(TARGET ${SHARE_IMAGE}_shared_property_target)
    get_property(
      ${var}
      TARGET   ${SHARE_IMAGE}_shared_property_target
      PROPERTY ${SHARE_PROPERTY}
    )
    set(${var} ${${var}} PARENT_SCOPE)
  endif()
endfunction()
