# cmake file

# options

set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-rpath /lib")

# general defs

set(SOURCES
  bar.cpp)


# directory level


# target level

add_library(bar ${SOURCES})

# this property is required by our parasitic targets
set_target_properties(bar PROPERTIES LINKER_LANGUAGE CXX)

target_include_directories(bar PUBLIC "../include")

target_compile_options(bar PUBLIC "-O0")

if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "5.0.0")
  target_compile_options(bar PUBLIC -Xclang -disable-O0-optnone)
endif()

set_target_properties(bar PROPERTIES
  CXX_STANDARD 11
  CXX_EXTENSIONS OFF)

# attachments on first target

llvmir_attach_bc_target(
  TARGET bar_bc
  DEPENDS bar)

llvmir_attach_opt_pass_target(
  TARGET bar_pass1
  DEPENDS bar_bc -mem2reg)

llvmir_attach_opt_pass_target(
  TARGET bar_pass2
  DEPENDS bar_pass1 -simplifycfg -licm)

llvmir_attach_opt_pass_target(
  TARGET bar_pass3
  DEPENDS bar_pass2 -licm)

llvmir_attach_disassemble_target(
  TARGET bar_dis
  DEPENDS bar_pass2)

llvmir_attach_assemble_target(
  TARGET bar_as
  DEPENDS bar_dis)

llvmir_attach_link_target(
  TARGET bar_llvmlink
  DEPENDS bar_pass2)

llvmir_attach_opt_pass_target(
  TARGET bar_pass4
  DEPENDS bar_llvmlink -simplifycfg)

llvmir_attach_library(
  TARGET bar_bc_lib
  DEPENDS bar_pass2 SHARED)


