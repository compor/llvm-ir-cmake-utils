# cmake file

# options

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0")


# general defs

set(SOURCES
  foo.cpp
  bar.cpp)


# directory level

add_definitions(-DDIR_FOO=1)

include_directories("${CMAKE_CURRENT_SOURCE_DIR}/../include/general")


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

target_include_directories(qux PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../include/detail")
target_include_directories(qux PUBLIC 
  "${CMAKE_CURRENT_SOURCE_DIR}/../include")


# attachments on first target

attach_llvmir_bc_target(qux_bc qux)

attach_llvmir_opt_pass_target(qux_pass1 qux_bc -mem2reg)
attach_llvmir_opt_pass_target(qux_pass2 qux_pass1 -simplifycfg -licm)
attach_llvmir_opt_pass_target(qux_pass3 qux_pass2 -licm)

attach_llvmir_disassemble_target(qux_dis qux_pass2)
attach_llvmir_assemble_target(qux_as qux_dis)

attach_llvmir_link_target(qux_llvmlink qux_pass2)

attach_llvmir_opt_pass_target(qux_pass4 qux_llvmlink -simplifycfg)

attach_llvmir_executable(qux_bc_exe qux_pass4)
attach_llvmir_executable(qux_bc_exe2 qux_pass2)

attach_llvmir_library(qux_bc_lib qux_pass2 SHARED)


