# LLVM IR utils for cmake

set(LLVM_IR_UTIL_VERSION_MAJOR "1")
set(LLVM_IR_UTIL_VERSION_MINOR "0")
set(LLVM_IR_UTIL_VERSION_PATCH "0")

set(LLVM_IR_UTIL_VERSION_STRING
  "${LLVM_IR_UTIL_VERSION_MAJOR}.${LLVM_IR_UTIL_VERSION_MINOR}.${LLVM_IR_UTIL_VERSION_PATCH}")


macro(LLVMIRSetup)
  set(LLVMIR_DIR "llvm-ir")

  set(LLVMIR_COMPILER "")
  set(LLVMIR_OPT "opt")
  set(LLVMIR_LINK "llvm-link")
  set(LLVMIR_ASSEMBLER "llvm-as")
  set(LLVMIR_DISASSEMBLER "llvm-dis")

  set(LLVMIR_BINARY_FMT_SUFFIX "bc")
  set(LLVMIR_TEXT_FMT_SUFFIX "ll")

  set(LLVMIR_TYPES LLVMIR_BINARY LLVMIR_TEXT)
  set(LLVMIR_FMT_SUFFICES ${LLVMIR_BINARY_FMT_SUFFIX} ${LLVMIR_TEXT_FMT_SUFFIX})
endmacro()


#

LLVMIRSetup()

#

function(attach_llvmir_target OUT_TRGT IN_TRGT)
  ## preamble
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")
  get_property(IN_FILES TARGET ${IN_TRGT} PROPERTY SOURCES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  list(GET LLVMIR_TYPES 0 OUT_LLVMIR_TYPE)
  list(GET LLVMIR_FMT_SUFFICES 0 OUT_LLVMIR_SUFFIX)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "")
    message(ERROR " Cannot attach ${OUT_TRGT} to an ${IN_LLVMIR_TYPE} target.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(ERROR " Linker language for target ${IN_TRGT} must be set.")
  endif()

  if("${LLVMIR_COMPILER}" STREQUAL "")
    set(LLVMIR_COMPILER ${CMAKE_${LINKER_LANGUAGE}_COMPILER})
  endif()

  ## command options

  # compile definitions
  set(SRC_DEFS "")

  # per directory
  get_property(SRC_DEFS_TMP DIRECTORY PROPERTY COMPILE_DEFINITIONS)
  foreach(DEF ${SRC_DEFS_TMP})
    list(APPEND SRC_DEFS -D${DEF})
  endforeach()

  get_property(SRC_DEFS_TMP DIRECTORY PROPERTY
    COMPILE_DEFINITIONS_${CMAKE_BUILD_TYPE})
  foreach(DEF ${SRC_DEFS_TMP})
    list(APPEND SRC_DEFS -D${DEF})
  endforeach()

  # per target
  get_property(SRC_DEFS_TMP TARGET ${IN_TRGT} PROPERTY COMPILE_DEFINITIONS)
  foreach(DEF ${SRC_DEFS_TMP})
    list(APPEND SRC_DEFS -D${DEF})
  endforeach()

  get_property(SRC_DEFS_TMP TARGET ${IN_TRGT} PROPERTY
    COMPILE_DEFINITIONS_${CMAKE_BUILD_TYPE})
  foreach(DEF ${SRC_DEFS_TMP})
    list(APPEND SRC_DEFS -D${DEF})
  endforeach()

  get_property(SRC_DEFS_TMP TARGET ${IN_TRGT} PROPERTY
    INTERFACE_COMPILE_DEFINITIONS)
  foreach(DEF ${SRC_DEFS_TMP})
    list(APPEND SRC_DEFS -D${DEF})
  endforeach()

  list(REMOVE_DUPLICATES SRC_DEFS)

  # compile options
  set(SRC_COMPILE_OPTIONS "")
  get_property(SRC_COMPILE_OPTIONS TARGET ${IN_TRGT} PROPERTY COMPILE_OPTIONS)

  # compile lang flags
  set(SRC_LANG_FLAGS_TMP ${CMAKE_${LINKER_LANGUAGE}_FLAGS_${CMAKE_BUILD_TYPE}})
  if("${SRC_LANG_FLAGS_TMP}" STREQUAL "")
    set(SRC_LANG_FLAGS_TMP ${CMAKE_${LINKER_LANGUAGE}_FLAGS})
  endif()

  # this transforms the string to a list and gets rid of the double quotes
  # when assembling the command arguments
  string(REPLACE " " ";" SRC_LANG_FLAGS "${SRC_LANG_FLAGS_TMP}")

  # compile flags
  # deprecated according to cmake docs
  get_property(SRC_FLAGS_TMP TARGET ${IN_TRGT} PROPERTY COMPILE_FLAGS)

  # this transforms the string to a list and gets rid of the double quotes
  # when assembling the command arguments
  string(REPLACE " " ";" SRC_FLAGS "${SRC_FLAGS_TMP}")

  # includes
  set(SRC_INCLUDES "")

  get_property(INC_DIRS TARGET ${IN_TRGT} PROPERTY INCLUDE_DIRECTORIES)
  foreach(DIR ${INC_DIRS})
    list(APPEND SRC_INCLUDES -I${DIR})
  endforeach()

  get_property(INC_DIRS TARGET ${IN_TRGT} PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
  foreach(DIR ${INC_DIRS})
    list(APPEND SRC_INCLUDES -I${DIR})
  endforeach()

  list(REMOVE_DUPLICATES SRC_INCLUDES)

  ## main action
  foreach(IN_FILE ${IN_FILES})
    get_filename_component(OUTFILE ${IN_FILE} NAME_WE)
    get_filename_component(INFILE ${IN_FILE} ABSOLUTE)
    set(OUT_LLVMIR_FILE "${OUTFILE}.${OUT_LLVMIR_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    # compile definitions per source file
    set(SRC_FILE_DEFS "")

    get_property(SRC_DEFS_TMP SOURCE ${INFILE} PROPERTY COMPILE_DEFINITIONS)
    foreach(DEF ${SRC_DEFS_TMP})
      list(APPEND SRC_FILE_DEFS -D${DEF})
    endforeach()

    get_property(SRC_DEFS_TMP SOURCE ${IN_TRGT} PROPERTY
      COMPILE_DEFINITIONS_${CMAKE_BUILD_TYPE})
    foreach(DEF ${SRC_DEFS_TMP})
      list(APPEND SRC_FILE_DEFS -D${DEF})
    endforeach()

    # compile flags per source file
    get_property(SRC_FLAGS_TMP SOURCE ${INFILE} PROPERTY COMPILE_FLAGS)

    # this transforms the string to a list and gets rid of the double quotes
    # when assembling the command arguments
    string(REPLACE " " ";" SRC_FILE_FLAGS "${SRC_FLAGS_TMP}")

    # stitch all args together
    set(CMD_ARGS -emit-llvm ${SRC_LANG_FLAGS} ${SRC_FLAGS} ${SRC_COMPILE_OPTIONS}
      ${SRC_FILE_FLAGS} ${SRC_FILE_DEFS} ${SRC_DEFS} ${SRC_INCLUDES})

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

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${OUT_LLVMIR_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})

  add_dependencies(${IN_TRGT} ${OUT_TRGT})
endfunction()

#

function(attach_llvmir_opt_pass_target OUT_TRGT IN_TRGT)
  ## preamble
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  list(GET LLVMIR_TYPES 0 OUT_LLVMIR_TYPE)
  list(GET LLVMIR_FMT_SUFFICES 0 OUT_LLVMIR_SUFFIX)
  list(GET LLVMIR_TYPES 0 IN_EXPECTED_LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${IN_EXPECTED_LLVMIR_TYPE}")
    message(ERROR " Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(ERROR " Linker language for target ${IN_TRGT} must be set.")
  endif()

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}-${OUT_TRGT}.${OUT_LLVMIR_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    ## main action
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

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${OUT_LLVMIR_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})

  add_dependencies(${IN_TRGT} ${OUT_TRGT})
endfunction()

#

function(attach_llvmir_disassemble_target OUT_TRGT IN_TRGT)
  ## preamble
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  list(GET LLVMIR_TYPES 1 OUT_LLVMIR_TYPE)
  list(GET LLVMIR_FMT_SUFFICES 1 OUT_LLVMIR_SUFFIX)
  list(GET LLVMIR_TYPES 0 IN_EXPECTED_LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${IN_EXPECTED_LLVMIR_TYPE}")
    message(ERROR " Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(ERROR " Linker language for target ${IN_TRGT} must be set.")
  endif()

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}.${LLVMIR_TEXT_FMT_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    ## main action
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

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${OUT_LLVMIR_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})

  add_dependencies(${IN_TRGT} ${OUT_TRGT})
endfunction()

#

function(attach_llvmir_assemble_target OUT_TRGT IN_TRGT)
  ## preamble
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(IN_LLVMIR_FILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  list(GET LLVMIR_TYPES 0 OUT_LLVMIR_TYPE)
  list(GET LLVMIR_FMT_SUFFICES 0 OUT_LLVMIR_SUFFIX)
  list(GET LLVMIR_TYPES 1 IN_EXPECTED_LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${IN_EXPECTED_LLVMIR_TYPE}")
    message(ERROR " Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(ERROR " Linker language for target ${IN_TRGT} must be set.")
  endif()

  foreach(IN_LLVMIR_FILE ${IN_LLVMIR_FILES})
    get_filename_component(OUTFILE ${IN_LLVMIR_FILE} NAME_WE)
    set(INFILE "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
    set(OUT_LLVMIR_FILE "${OUTFILE}.${OUT_LLVMIR_SUFFIX}")
    set(FULL_OUT_LLVMIR_FILE "${WORK_DIR}/${OUT_LLVMIR_FILE}")

    ## main action
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

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${OUT_LLVMIR_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})

  add_dependencies(${IN_TRGT} ${OUT_TRGT})
endfunction()

#

function(attach_llvmir_link_target OUT_TRGT IN_TRGT)
  ## preamble
  set(WORK_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY ${WORK_DIR})

  set(OUT_LLVMIR_FILES "")
  set(FULL_OUT_LLVMIR_FILES "")
  get_property(INFILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  list(GET LLVMIR_TYPES 0 OUT_LLVMIR_TYPE)
  list(GET LLVMIR_FMT_SUFFICES 0 OUT_LLVMIR_SUFFIX)
  list(GET LLVMIR_TYPES 0 IN_EXPECTED_LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${IN_EXPECTED_LLVMIR_TYPE}")
    message(ERROR " Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(ERROR " Linker language for target ${IN_TRGT} must be set.")
  endif()

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

  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_TYPE ${OUT_LLVMIR_TYPE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_DIR ${WORK_DIR})
  set_property(TARGET ${OUT_TRGT} PROPERTY LLVMIR_FILES ${OUT_LLVMIR_FILES})
  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})

  add_dependencies(${IN_TRGT} ${OUT_TRGT})

  ## main action
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


function(attach_llvmir_executable OUT_TRGT IN_TRGT)
  ## preamble
  set(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY "${OUT_DIR}")

  get_property(INFILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  list(GET LLVMIR_TYPES 0 IN_EXPECTED_LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${IN_EXPECTED_LLVMIR_TYPE}")
    message(ERROR " Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(ERROR " Linker language for target ${IN_TRGT} must be set.")
  endif()

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  add_executable(${OUT_TRGT} "${ARGN}" "${IN_FULL_LLVMIR_FILES}")

  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY RUNTIME_OUTPUT_DIRECTORY ${OUT_DIR})

  # this marks the object as to be linked but not compiled
  foreach(IN_FULL_LLVMIR_FILE ${IN_FULL_LLVMIR_FILES})
    set_property(SOURCE ${IN_FULL_LLVMIR_FILE} PROPERTY EXTERNAL_OBJECT TRUE)
  endforeach()

  add_dependencies(${IN_TRGT} ${OUT_TRGT})

  ## postamble
endfunction()

#

function(attach_llvmir_library OUT_TRGT IN_TRGT)
  ## preamble
  set(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${LLVMIR_DIR}/${OUT_TRGT}")
  file(MAKE_DIRECTORY "${OUT_DIR}")

  get_property(INFILES TARGET ${IN_TRGT} PROPERTY LLVMIR_FILES)
  get_property(IN_LLVMIR_DIR TARGET ${IN_TRGT} PROPERTY LLVMIR_DIR)
  get_property(LINKER_LANGUAGE TARGET ${IN_TRGT} PROPERTY LINKER_LANGUAGE)
  get_property(IN_LLVMIR_TYPE TARGET ${IN_TRGT} PROPERTY LLVMIR_TYPE)

  list(GET LLVMIR_TYPES 0 IN_EXPECTED_LLVMIR_TYPE)

  if(NOT "${IN_LLVMIR_TYPE}" STREQUAL "${IN_EXPECTED_LLVMIR_TYPE}")
    message(ERROR " Cannot attach ${OUT_TRGT} to a ${IN_LLVMIR_TYPE} target.")
  endif()

  if("${LINKER_LANGUAGE}" STREQUAL "")
    message(ERROR " Linker language for target ${IN_TRGT} must be set.")
  endif()

  set(IN_FULL_LLVMIR_FILES "")
  foreach(IN_LLVMIR_FILE ${INFILES})
    list(APPEND IN_FULL_LLVMIR_FILES "${IN_LLVMIR_DIR}/${IN_LLVMIR_FILE}")
  endforeach()

  add_library(${OUT_TRGT} "${ARGN}" "${IN_FULL_LLVMIR_FILES}")

  set_property(TARGET ${OUT_TRGT} PROPERTY LINKER_LANGUAGE ${LINKER_LANGUAGE})
  set_property(TARGET ${OUT_TRGT} PROPERTY LIBRARY_OUTPUT_DIRECTORY ${OUT_DIR})

  # this marks the object as to be linked but not compiled
  foreach(IN_FULL_LLVMIR_FILE ${IN_FULL_LLVMIR_FILES})
    set_property(SOURCE ${IN_FULL_LLVMIR_FILE} PROPERTY EXTERNAL_OBJECT TRUE)
  endforeach()

  add_dependencies(${IN_TRGT} ${OUT_TRGT})

  ## postamble
endfunction()

