# cmake file

# options

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-inline")


# general defs

set(SOURCES
  foo.cpp
  bar.cpp)


# directory level

add_definitions(-DDIR_FOO=1)

include_directories("../include/general")


# target level

add_executable(qux ${SOURCES})
#add_library(qux ${SOURCES})

# this property is required by our parasitic targets
set_target_properties(qux PROPERTIES LINKER_LANGUAGE CXX)

target_compile_definitions(qux PUBLIC TARGET_PUB_FOO=2)
target_compile_definitions(qux PRIVATE TARGET_PRIV_FOO=3)

# this seems not to be used in add_executable/add_library
#target_compile_definitions(qux INTERFACE TARGET_IF_FOO=4)
target_compile_definitions(qux PUBLIC TARGET_IF_FOO=4)

target_compile_options(qux PUBLIC -Wnonnull)
target_compile_options(qux PRIVATE -Wfloat-conversion)
target_compile_options(qux INTERFACE -Wpedantic)

target_include_directories(qux PRIVATE "../include/detail")
target_include_directories(qux PUBLIC "../include")


# attachments on first target

llvmir_attach_bc_target(qux_bc qux)
add_dependencies(qux_bc qux)

llvmir_attach_opt_pass_target(qux_pass1 qux_bc -mem2reg)
add_dependencies(qux_pass1 qux_bc)

llvmir_attach_opt_pass_target(qux_pass2 qux_pass1 -simplifycfg -licm)
add_dependencies(qux_pass2 qux_pass1)

llvmir_attach_opt_pass_target(qux_pass3 qux_pass2 -licm)
add_dependencies(qux_pass3 qux_pass2)

llvmir_attach_disassemble_target(qux_dis qux_pass2)
add_dependencies(qux_dis qux_pass2)

llvmir_attach_assemble_target(qux_as qux_dis)
add_dependencies(qux_as qux_dis)

llvmir_attach_link_target(qux_llvmlink qux_pass2)
add_dependencies(qux_llvmlink qux_pass2)

llvmir_attach_opt_pass_target(qux_pass4 qux_llvmlink -simplifycfg)
add_dependencies(qux_pass4 qux_llvmlink)

llvmir_attach_executable(qux_bc_exe qux_pass4)
add_dependencies(qux_bc_exe qux_pass4)

llvmir_attach_executable(qux_bc_exe2 qux_pass2)
add_dependencies(qux_bc_exe2 qux_pass2)

llvmir_attach_library(qux_bc_lib qux_pass2 SHARED)
add_dependencies(qux_bc_lib qux_pass2)


add_custom_target(qux_pipeline1 DEPENDS
  qux_pass1)

add_custom_target(qux_pipeline2 DEPENDS
  qux_pass2)

set_property(TARGET qux_pipeline2 PROPERTY EXCLUDE_FROM_ALL OFF)

