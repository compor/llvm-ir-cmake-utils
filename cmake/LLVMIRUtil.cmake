#.rst:
#LLVM-IR-Util
# -------------
#
# LLVM IR utils for cmake

cmake_minimum_required(VERSION 2.8.11)

include(LLVMIRUtilInternal)


set(LLVM_IR_UTIL_VERSION_MAJOR "2")
set(LLVM_IR_UTIL_VERSION_MINOR "0")
set(LLVM_IR_UTIL_VERSION_PATCH "2")

string(CONCAT LLVM_IR_UTIL_VERSION
  ${LLVM_IR_UTIL_VERSION_MAJOR} "."
  ${LLVM_IR_UTIL_VERSION_MINOR} "."
  ${LLVM_IR_UTIL_VERSION_PATCH})


###

llvmir_setup()

###


# public (client) interface macros/functions

function(llvmir_attach_bc_target OUT_TRGT IN_TRGT)
  ## preamble
  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  llvmir_check_non_llvmir_target_properties(${IN_TRGT})

  # the 3.x and above INTERFACE_SOURCES does not participate in the compilation
  # of a target

  # if the property does not exist the related variable is not defined
  get_property(IN_FILES TARGET ${IN_TRGT} PROPERTY SOURCES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)

  debug("@llvmir_attach_bc_target ${IN_TRGT} linker lang: ${LINKER_LANGUAGE}")

  llvmir_set_compiler(${LINKER_LANGUAGE})

  ## command options
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  # compile definitions
  llvmir_extract_compile_defs_properties(IN_DEFS ${IN_TRGT})

  # includes
  llvmir_extract_include_dirs_properties(IN_INCLUDES ${IN_TRGT})

  # language standards flags
  llvmir_extract_standard_flags(IN_STANDARD_FLAGS ${IN_TRGT})

  # compile options
  llvmir_extract_compile_option_properties(IN_COMPILE_OPTIONS ${IN_TRGT})

  # compile flags
  llvmir_extract_compile_flags(IN_COMPILE_FLAGS ${IN_TRGT})

  # compile lang flags
  llvmir_extract_lang_flags(IN_LANG_FLAGS ${LINKER_LANGUAGE})

  ## main operations
  foreach(IN_FILE ${IN_FILES})
    get_filename_component(OUTFILE ${IN_FILE} NAME_WE)
    get_filename_component(INFILE ${IN_FILE} ABSOLUTE)
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_BINARY_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    # compile definitions per source file
    llvmir_extract_compile_defs_properties(IN_FILE_DEFS ${IN_FILE})

    # compile flags per source file
    llvmir_extract_lang_flags(IN_FILE_COMPILE_FLAGS ${IN_FILE})

    # stitch all args together
    catuniq(CURRENT_DEFS ${IN_DEFS} ${IN_FILE_DEFS})
    debug("@llvmir_attach_bc_target ${IN_TRGT} defs: ${CURRENT_DEFS}")

    catuniq(CURRENT_COMPILE_FLAGS ${IN_COMPILE_FLAGS} ${IN_FILE_COMPILE_FLAGS})
    debug("@llvmir_attach_bc_target ${IN_TRGT} compile flags: \
      ${CURRENT_COMPILE_FLAGS}")

      set(CMD_ARGS "-emit-llvm" ${IN_STANDARD_FLAGS} ${IN_LANG_FLAGS}
        ${IN_COMPILE_OPTIONS} ${CURRENT_COMPILE_FLAGS} ${CURRENT_DEFS}
        ${IN_INCLUDES})

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_COMPILER}
      ARGS ${CMD_ARGS} -c ${INFILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${INFILE}
      IMPLICIT_DEPENDS ${LINKER_LANGUAGE} ${INFILE}
      COMMENT "Generating LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble
  # clean up
  set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES
    ${FULL_OUT_LLVMIR_FILES})

  # setup custom target
  add_custom_target(${OUT_TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY EXCLUDE_FROM_ALL On)
endfunction()

#

function(llvmir_attach_opt_pass_target OUT_TRGT IN_TRGT)
  ## preamble
  llvmir_check_target_properties(${IN_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    fatal("Cannot attach ${OUT_TRGT} to target of type: ${IN_LLVMIR_TYPE}.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    fatal("Linker language for target ${IN_TRGT} must be set.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}-${OUT_TRGT}.${LLVMIR_BINARY_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_OPT}
      ARGS ${ARGN} ${INFILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${INFILE}
      COMMENT "Generating LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble
  # clean up
  set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES
    ${FULL_OUT_LLVMIR_FILES})

  # setup custom target
  add_custom_target(${OUT_TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY EXCLUDE_FROM_ALL On)
endfunction()

#

function(llvmir_attach_disassemble_target OUT_TRGT IN_TRGT)
  ## preamble
  llvmir_check_target_properties(${IN_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    fatal("Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_TEXT_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_DISASSEMBLER}
      ARGS ${ARGN} ${INFILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${INFILE}
      COMMENT "Disassembling LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble

  # clean up
  set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES
    ${FULL_OUT_LLVMIR_FILES})

  # setup custom target
  add_custom_target(${OUT_TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_TEXT_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY EXCLUDE_FROM_ALL On)
endfunction()

#

function(llvmir_attach_assemble_target OUT_TRGT IN_TRGT)
  ## preamble
  llvmir_check_target_properties(${IN_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_TEXT_TYPE}")
    fatal("Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_BINARY_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
      COMMAND ${LLVMIR_ASSEMBLER}
      ARGS ${ARGN} ${INFILE} -o ${FULL_OUT_LLVMIR_FILE}
      DEPENDS ${INFILE}
      COMMENT "Assembling LLVM bitcode ${OUT_LLVMIR_FILE}"
      VERBATIM)

    list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
    list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})
  endforeach()

  ## postamble

  # clean up
  set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES
    ${FULL_OUT_LLVMIR_FILES})

  # setup custom target
  add_custom_target(${OUT_TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY EXCLUDE_FROM_ALL On)
endfunction()

#

function(llvmir_attach_link_target OUT_TRGT IN_TRGT)
  ## preamble
  llvmir_check_target_properties(${IN_TRGT})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")

  get_property(INFILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    fatal("Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_TRGT}.${LLVMIR_BINARY_FMT_SUFFIX}")
  get_filename_component(OUT_LLVMIR_FILE ${FULL_OUT_LLVMIR_FILE} NAME)

  list(APPEND OUT_LLVMIR_FILES ${OUT_LLVMIR_FILE})
  list(APPEND FULL_OUT_LLVMIR_FILES ${FULL_OUT_LLVMIR_FILE})

  # setup custom target
  add_custom_target(${OUT_TRGT} DEPENDS ${FULL_OUT_LLVMIR_FILES})

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${LLVMIR_BINARY_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY EXCLUDE_FROM_ALL On)

  add_custom_command(OUTPUT ${FULL_OUT_LLVMIR_FILE}
    COMMAND llvm-link
    ARGS ${ARGN} -o ${FULL_OUT_LLVMIR_FILE} ${IN_FULL_LLVMIR_FILES}
    DEPENDS ${IN_FULL_LLVMIR_FILES}
    COMMENT "Linking LLVM bitcode ${OUT_LLVMIR_FILE}"
    VERBATIM)

  ## postamble
  # clean up
  set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES
    ${FULL_OUT_LLVMIR_FILES})
endfunction()


function(llvmir_attach_executable OUT_TRGT IN_TRGT)
  ## preamble
  llvmir_check_target_properties(${IN_TRGT})

  get_property(INFILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    fatal("Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY "${OUT_DIR}")

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  add_executable(${OUT_TRGT} ${ARGN} ${IN_FULL_LLVMIR_FILES})

  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY RUNTIME_OUTPUT_DIRECTORY ${OUT_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY EXCLUDE_FROM_ALL On)

  # this marks the object as to be linked but not compiled
  foreach(IN_FULL_LLVMIR_FILE ${IN_FULL_LLVMIR_FILES})
    set_property(SOURCE ${IN_FULL_LLVMIR_FILE} PROPERTY EXTERNAL_OBJECT TRUE)
  endforeach()

  ## postamble
endfunction()

#

function(llvmir_attach_library OUT_TRGT IN_TRGT)
  ## preamble
  llvmir_check_target_properties(${IN_TRGT})

  get_property(INFILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${LLVMIR_BINARY_TYPE}")
    fatal("Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  ## main operations
  set(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY "${OUT_DIR}")

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  add_library(${OUT_TRGT} ${ARGN} ${IN_FULL_LLVMIR_FILES})

  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LIBRARY_OUTPUT_DIRECTORY ${OUT_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY EXCLUDE_FROM_ALL On)

  # this marks the object as to be linked but not compiled
  foreach(IN_FULL_LLVMIR_FILE ${IN_FULL_LLVMIR_FILES})
    set_property(SOURCE ${IN_FULL_LLVMIR_FILE} PROPERTY EXTERNAL_OBJECT TRUE)
  endforeach()

  ## postamble
endfunction()

