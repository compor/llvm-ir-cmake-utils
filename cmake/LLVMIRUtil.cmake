#.rst:
#LLVM-IR-Util
# -------------
#
# LLVM IR utils for cmake

cmake_minimum_required(VERSION 3.0.0)

include(CMakeParseArguments)

include(LLVMIRUtilInternal)

###

llvmir_setup()

###


# public (client) interface macros/functions

function(llvmir_attach_bc_target)
  set(options ATTACH_TO_DEPENDENT_STATIC_LIBS)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    set(TRGT ${ARGV0})
    set(DEPENDS_TRGT ${ARGV1})

    if(${ARGC} GREATER 3)
      message(FATAL_ERROR "llvmir_attach_bc_target: \
      extraneous arguments provided")
    endif()
  else()
    if(LLVMIR_ATTACH_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "llvmir_attach_bc_target: \
      extraneous arguments provided")
    endif()
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_bc_target: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_bc_target: missing DEPENDS option")
  endif()

  ## preamble
  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  llvmir_check_non_llvmir_target_properties(${DEPENDS_TRGT})

  # the 3.x and above INTERFACE_SOURCES does not participate in the compilation
  # of a target

  # if the property does not exist the related variable is not defined
  get_property(IN_FILES TARGET ${DEPENDS_TRGT} PROPERTY SOURCES)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(EXTERNAL_TYPE TARGET ${DEPENDS_TRGT} PROPERTY TYPE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  debug(
    "@llvmir_attach_bc_target ${DEPENDS_TRGT} linker lang: ${LINKER_LANGUAGE}")

  llvmir_set_compiler(${LINKER_LANGUAGE})

  ## command options
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  # compile definitions
  llvmir_extract_compile_defs_properties(IN_DEFS ${DEPENDS_TRGT})

  # includes
  llvmir_extract_include_dirs_properties(IN_INCLUDES ${DEPENDS_TRGT})

  # language standards flags
  llvmir_extract_standard_flags(IN_STANDARD_FLAGS
    ${DEPENDS_TRGT} ${LINKER_LANGUAGE})

  # compile options
  llvmir_extract_compile_option_properties(IN_COMPILE_OPTIONS ${DEPENDS_TRGT})

  # compile flags
  llvmir_extract_compile_flags(IN_COMPILE_FLAGS ${DEPENDS_TRGT})

  # compile lang flags
  llvmir_extract_lang_flags(IN_LANG_FLAGS ${LINKER_LANGUAGE})

  # Link static libraries
  if(LLVMIR_ATTACH_ATTACH_TO_DEPENDENT_STATIC_LIBS)
    message(STATUS "ATTACH_TO_DEPENDENT_STATIC_LIBS option is turned on. Attaching to dependent static libraries of target ${TRGT}.")

    # Find statically linked libraries, and add the source files for IR generation
    foreach(LINK_LIB ${LINK_LIBRARIES})
      if(TARGET ${LINK_LIB})
        get_target_property(type ${LINK_LIB} TYPE)

        # Check the library is a static one. For shared libraries, we cannot get the source files for compiling.
        if(${type} STREQUAL "STATIC_LIBRARY")
          get_property(LINK_LIB_FILES TARGET ${LINK_LIB} PROPERTY SOURCES)
          message(STATUS "Attaching to dependent static library ${LINK_LIB} of target ${TRGT}.")

          foreach(LINK_LIB_FILE ${LINK_LIB_FILES})
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${LINK_LIB_FILE}")
              list(APPEND IN_FILES ${LINK_LIB_FILE})
              message(STATUS "Add file from static library: ${LINK_LIB_FILE}")
            endif()
          endforeach()
        endif()
      endif()
    endforeach()

    list(REMOVE_DUPLICATES IN_FILES)
  endif()

  set(header_exts ".h;.hh;.hpp;.h++;.hxx")
  set(temp_include_dirs "")

  # Find all header files in the source
  foreach(IN_FILE ${IN_FILES})
    get_filename_component(FILE_EXT ${IN_FILE} LAST_EXT)
    get_filename_component(FILE_DIR ${IN_FILE} DIRECTORY)
    string(TOLOWER ${FILE_EXT} FILE_EXT)
    list(FIND header_exts ${FILE_EXT} _index)

    if(${_index} GREATER -1)
      message(WARNING "A header file ${IN_FILE} is found in source files! Please add header directories using target_include_directories() instead.")

      # Add to include list
      list(APPEND temp_include_dirs "-I${FILE_DIR}")
    endif()
  endforeach()

  if(temp_include_dirs)
    list(REMOVE_DUPLICATES temp_include_dirs)
    message(WARNING "\"${temp_include_dirs}\" added to include directories.")

    list(APPEND IN_INCLUDES ${temp_include_dirs})
    list(REMOVE_DUPLICATES IN_INCLUDES)
  endif()

  # main operations
  foreach(IN_FILE ${IN_FILES})
    get_target_property(SOURCE_DIR ${DEPENDS_TRGT} SOURCE_DIR)
    get_filename_component(ABS_IN_FILE ${IN_FILE} ABSOLUTE BASE_DIR ${SOURCE_DIR})

    # Skip header files
    get_filename_component(FILE_EXT ${ABS_IN_FILE} LAST_EXT)
    string(TOLOWER ${FILE_EXT} FILE_EXT)

    list (FIND header_exts ${FILE_EXT} _index)
    if(${_index} GREATER -1)
      continue()
    endif()

    get_filename_component(OUTFILE ${ABS_IN_FILE} NAME)
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_BINARY_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    # compile definitions per source file
    llvmir_extract_compile_defs_properties(IN_FILE_DEFS ${ABS_IN_FILE})

    # compile flags per source file
    llvmir_extract_lang_flags(IN_FILE_COMPILE_FLAGS ${ABS_IN_FILE})

    # stitch all args together
    catuniq(CURRENT_DEFS ${IN_DEFS} ${IN_FILE_DEFS})
    debug("@llvmir_attach_bc_target ${DEPENDS_TRGT} defs: ${CURRENT_DEFS}")

    catuniq(CURRENT_COMPILE_FLAGS ${IN_COMPILE_FLAGS} ${IN_FILE_COMPILE_FLAGS})
    debug("@llvmir_attach_bc_target ${DEPENDS_TRGT} compile flags: \
    ${CURRENT_COMPILE_FLAGS}")

    set(CMD_ARGS "-emit-llvm" ${IN_STANDARD_FLAGS} ${IN_LANG_FLAGS}
      ${IN_COMPILE_OPTIONS} ${CURRENT_COMPILE_FLAGS} ${CURRENT_DEFS}
      ${IN_INCLUDES})

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_COMPILER}
      ARGS ${CMD_ARGS} -c ${ABS_IN_FILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${ABS_IN_FILE}
      IMPLICIT_DEPENDS ${LINKER_LANGUAGE} ${ABS_IN_FILE}
      COMMENT "Generating LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble

  # setup custom target
  add_custom_target(${TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_EXTERNAL_TYPE ${EXTERNAL_TYPE})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY
    LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})
endfunction()

#

function(llvmir_attach_opt_pass_target)
  set(options)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 1 DEPENDS_TRGT)
    list(REMOVE_AT LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 1)
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_opt_pass_target: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_opt_pass_target: missing DEPENDS option")
  endif()

  ## preamble
  llvmir_check_target_properties(${DEPENDS_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_TYPE TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_TYPE)
  get_property(LLVMIR_EXTERNAL_TYPE TARGET ${DEPENDS_TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE)
  get_property(IN_LLVMIR_DIR TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    message(FATAL_ERROR "Cannot attach ${TRGT} to target of type: \
    ${IN_LLVMIR_TYPE}.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(FATAL_ERROR "Linker language for target ${DEPENDS_TRGT} \
    must be set.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_BINARY_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_OPT}
      ARGS
      ${LLVMIR_ATTACH_UNPARSED_ARGUMENTS} ${INFILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${INFILE}
      COMMENT "Generating LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble

  # setup custom target
  add_custom_target(${TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE ${LLVMIR_EXTERNAL_TYPE})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY
    LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})
endfunction()

#

function(llvmir_attach_disassemble_target)
  set(options)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 1 DEPENDS_TRGT)
    list(REMOVE_AT LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 1)
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_disassemble_target: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_disassemble_target: missing DEPENDS option")
  endif()

  ## preamble
  llvmir_check_target_properties(${DEPENDS_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_TYPE TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_TYPE)
  get_property(LLVMIR_EXTERNAL_TYPE TARGET ${DEPENDS_TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE)
  get_property(IN_LLVMIR_DIR TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    message(FATAL_ERROR "Cannot attach ${TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_TEXT_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_DISASSEMBLER}
      ARGS
      ${LLVMIR_ATTACH_UNPARSED_ARGUMENTS} ${INFILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${INFILE}
      COMMENT "Disassembling LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble

  # setup custom target
  add_custom_target(${TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_TEXT_TYPE})
  set_property(TARGET ${TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE ${LLVMIR_EXTERNAL_TYPE})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY
    LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})
endfunction()

#

function(llvmir_attach_assemble_target)
  set(options)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 1 DEPENDS_TRGT)
    list(REMOVE_AT LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 1)
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_assemble_target: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_assemble_target: missing DEPENDS option")
  endif()

  ## preamble
  llvmir_check_target_properties(${DEPENDS_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_TYPE TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_TYPE)
  get_property(LLVMIR_EXTERNAL_TYPE TARGET ${DEPENDS_TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE)
  get_property(IN_LLVMIR_DIR TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_TEXT_TYPE}")
    message(FATAL_ERROR "Cannot attach ${TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_BINARY_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_ASSEMBLER}
      ARGS
      ${LLVMIR_ATTACH_UNPARSED_ARGUMENTS} ${INFILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${INFILE}
      COMMENT "Assembling LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble

  # setup custom target
  add_custom_target(${TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE ${LLVMIR_EXTERNAL_TYPE})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY
    LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})
endfunction()

#

function(llvmir_attach_link_target)
  set(options)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 1 DEPENDS_TRGT)
    list(REMOVE_AT LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 1)
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_link_target: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_link_target: missing DEPENDS option")
  endif()

  ## preamble
  llvmir_check_target_properties(${DEPENDS_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_TYPE TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_TYPE)
  get_property(LLVMIR_EXTERNAL_TYPE TARGET ${DEPENDS_TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE)
  get_property(INFILES TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    message(FATAL_ERROR "Cannot attach ${TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${TRGT}.${LLVMIR_BINARY_FMT_SUFFIX}")
  if(SHORT_NAME)
    set(FULL_OUT_LLVMIR_FILE
      "${WORK_DIR}/${SHORT_NAME}.${LLVMIR_BINARY_FMT_SUFFIX}")
  endif()
  get_filename_component(OUT_LLVMIR_FILE ${FULL_OUT_LLVMIR_FILE} NAME)

  list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
  list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})

  # setup custom target
  add_custom_target(${TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE ${LLVMIR_EXTERNAL_TYPE})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY
    LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})

  add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
    COMMAND ${LLVMIR_LINK}
    ARGS
    ${LLVMIR_ATTACH_UNPARSED_ARGUMENTS}
    -o ${FULL_OUT_LLVMIR_FILE} ${IN_FULL_LLVMIR_FILES}
    DEPENDS ${IN_FULL_LLVMIR_FILES}
    COMMENT "Linking LLVM bitcode ${OUT_LLVMIR_FILE}"
    VERBATIM)

  ## postamble
endfunction()

function(llvmir_attach_obj_target)
  set(options)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 1 DEPENDS_TRGT)
    list(REMOVE_AT LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 1)
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_obj_target: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_obj_target: missing DEPENDS option")
  endif()

  ## preamble
  llvmir_check_target_properties(${DEPENDS_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_TYPE TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_TYPE)
  get_property(LLVMIR_EXTERNAL_TYPE TARGET ${DEPENDS_TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE)
  get_property(INFILES TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    message(FATAL_ERROR "Cannot attach ${TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${TRGT}.o")
  if(SHORT_NAME)
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${SHORT_NAME}.o")
  endif()
  get_filename_component(OUT_LLVMIR_FILE ${FULL_OUT_LLVMIR_FILE} NAME)

  list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
  list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})

  # setup custom target
  add_custom_target(${TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_OBJECT_TYPE})
  set_property(TARGET ${TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE ${LLVMIR_EXTERNAL_TYPE})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  set_property(TARGET ${TRGT}
    PROPERTY
    LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})

  add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
    COMMAND llc
    ARGS
    -filetype=obj
    ${LLVMIR_ATTACH_UNPARSED_ARGUMENTS}
    -o ${FULL_OUT_LLVMIR_FILE} ${IN_FULL_LLVMIR_FILES}
    DEPENDS ${IN_FULL_LLVMIR_FILES}
    COMMENT "Generating object ${OUT_LLVMIR_FILE}"
    VERBATIM)

  ## postamble
endfunction()

function(llvmir_attach_executable)
  set(options)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    set(TRGT ${ARGV0})
    set(DEPENDS_TRGT ${ARGV1})

    if(${ARGC} GREATER 3)
      message(FATAL_ERROR
        "llvmir_attach_executable: extraneous arguments provided")
    endif()
  else()
    if(LLVMIR_ATTACH_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR
        "llvmir_attach_executable: extraneous arguments provided")
    endif()
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_executable: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_executable: missing DEPENDS option")
  endif()

  ## preamble
  llvmir_check_target_properties(${DEPENDS_TRGT})

  get_property(IN_LLVMIR_TYPE TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_TYPE)
  get_property(LLVMIR_EXTERNAL_TYPE TARGET ${DEPENDS_TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE)
  get_property(INFILES TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}" AND
      NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_OBJECT_TYPE}")
    message(FATAL_ERROR "Cannot attach ${TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY "${OUT_DIR}")

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()


  add_executable(${TRGT} ${IN_FULL_LLVMIR_FILES})

  if(SHORT_NAME)
    set_property(TARGET ${TRGT} PROPERTY OUTPUT_NAME ${SHORT_NAME})
  endif()

  # simply setting the property does not seem to work
  #set_property(TARGET ${TRGT}
  #PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  #set_property(TARGET ${TRGT}
  #PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  #set_property(TARGET ${TRGT}
  #PROPERTY
  #LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
  #${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})

  # FIXME: cmake bags PUBLIC link dependencies under both interface and private
  # target properties, so for an exact propagation it is required to search for
  # elements that are only in the INTERFACE properties and set them as such
  # correctly with the target_link_libraries command
  if(INTERFACE_LINK_LIBRARIES)
    target_link_libraries(${TRGT} PUBLIC ${INTERFACE_LINK_LIBRARIES})
  endif()
  if(LINK_INTERFACE_LIBRARIES)
    target_link_libraries(${TRGT} PUBLIC ${LINK_INTERFACE_LIBRARIES})
  endif()
  if(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
    target_link_libraries(${TRGT}
      PUBLIC ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  endif()

  set_property(TARGET ${TRGT} PROPERTY RUNTIME_OUTPUT_DIRECTORY ${OUT_DIR})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})

  # this marks the object as to be linked but not compiled
  foreach(IN_FULL_LLVMIR_FILE ${IN_FULL_LLVMIR_FILES})
    set_property(SOURCE ${IN_FULL_LLVMIR_FILE} PROPERTY EXTERNAL_OBJECT TRUE)
  endforeach()

  ## postamble
endfunction()

#

function(llvmir_attach_library)
  set(options)
  set(oneValueArgs TARGET DEPENDS)
  set(multiValueArgs)
  cmake_parse_arguments(LLVMIR_ATTACH
    "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TRGT ${LLVMIR_ATTACH_TARGET})
  set(DEPENDS_TRGT ${LLVMIR_ATTACH_DEPENDS})

  # fallback to backwards compatible mode for argument parsing
  if(NOT TRGT AND NOT DEPENDS_TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 TRGT)
    list(GET LLVMIR_ATTACH_UNPARSED_ARGUMENTS 1 DEPENDS_TRGT)
    list(REMOVE_AT LLVMIR_ATTACH_UNPARSED_ARGUMENTS 0 1)
  endif()

  if(NOT TRGT)
    message(FATAL_ERROR "llvmir_attach_library: missing TARGET option")
  endif()

  if(NOT DEPENDS_TRGT)
    message(FATAL_ERROR "llvmir_attach_library: missing DEPENDS option")
  endif()

  ## preamble
  llvmir_check_target_properties(${DEPENDS_TRGT})

  get_property(IN_LLVMIR_TYPE TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_TYPE)
  get_property(LLVMIR_EXTERNAL_TYPE TARGET ${DEPENDS_TRGT}
    PROPERTY LLVMIR_EXTERNAL_TYPE)
  get_property(INFILES TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${DEPENDS_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(LINK_DEPENDS TARGET ${DEPENDS_TRGT} PROPERTY LINK_DEPENDS)
  get_property(LINK_FLAGS TARGET ${DEPENDS_TRGT} PROPERTY LINK_FLAGS)
  get_property(LINK_FLAGS_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE})
  get_property(INTERFACE_LINK_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY INTERFACE_LINK_LIBRARIES)
  get_property(LINK_LIBRARIES TARGET ${DEPENDS_TRGT} PROPERTY LINK_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES)
  get_property(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
    TARGET ${DEPENDS_TRGT}
    PROPERTY LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
  get_property(SHORT_NAME TARGET ${DEPENDS_TRGT} PROPERTY LLVMIR_SHORT_NAME)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}" AND
      NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_OBJECT_TYPE}")
    message(FATAL_ERROR "Cannot attach ${TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${TRGT}")
  file(MAKE_DIRECTORY "${OUT_DIR}")

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  # currenly unparsed args holds the library mode, e.g. SHARED, STATIC, etc
  add_library(${TRGT}
    ${LLVMIR_ATTACH_UNPARSED_ARGUMENTS} ${IN_FULL_LLVMIR_FILES})

  if(SHORT_NAME)
    set_property(TARGET ${TRGT} PROPERTY OUTPUT_NAME ${SHORT_NAME})
  endif()

  # simply setting the property does not seem to work
  #set_property(TARGET ${TRGT}
  #PROPERTY INTERFACE_LINK_LIBRARIES ${INTERFACE_LINK_LIBRARIES})
  #set_property(TARGET ${TRGT}
  #PROPERTY LINK_INTERFACE_LIBRARIES ${LINK_INTERFACE_LIBRARIES})
  #set_property(TARGET ${TRGT}
  #PROPERTY
  #LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}
  #${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})

  # FIXME: cmake bags PUBLIC link dependencies under both interface and private
  # target properties, so for an exact propagation it is required to search for
  # elements that are only in the INTERFACE properties and set them as such
  # correctly with the target_link_libraries command
  if(INTERFACE_LINK_LIBRARIES)
    target_link_libraries(${TRGT} PUBLIC ${INTERFACE_LINK_LIBRARIES})
  endif()
  if(LINK_INTERFACE_LIBRARIES)
    target_link_libraries(${TRGT} PUBLIC ${LINK_INTERFACE_LIBRARIES})
  endif()
  if(LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE})
    target_link_libraries(${TRGT}
      PUBLIC ${LINK_INTERFACE_LIBRARIES_${CMAKE_BUILD_TYPE}})
  endif()

  set_property(TARGET ${TRGT} PROPERTY LIBRARY_OUTPUT_DIRECTORY ${OUT_DIR})
  set_property(TARGET ${TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${TRGT} PROPERTY LINK_DEPENDS ${LINK_DEPENDS})
  set_property(TARGET ${TRGT} PROPERTY LINK_FLAGS ${LINK_FLAGS})
  set_property(TARGET ${TRGT}
    PROPERTY LINK_FLAGS_${CMAKE_BUILD_TYPE} ${LINK_FLAGS_${CMAKE_BUILD_TYPE}})
  set_property(TARGET ${TRGT} PROPERTY EXCLUDE_FROM_ALL On)
  set_property(TARGET ${TRGT} PROPERTY LLVMIR_SHORT_NAME ${SHORT_NAME})

  # this marks the object as to be linked but not compiled
  foreach(IN_FULL_LLVMIR_FILE ${IN_FULL_LLVMIR_FILES})
    set_property(SOURCE ${IN_FULL_LLVMIR_FILE} PROPERTY EXTERNAL_OBJECT TRUE)
  endforeach()

  ## postamble
endfunction()

