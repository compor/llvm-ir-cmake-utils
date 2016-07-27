# cmake file

# general defs

set(SOURCES
  foo.cpp
  bar.cpp)


# directory level

add_definitions(-DDIR_FOO=1)


# target level

add_executable(qux ${SOURCES})

# this property is required by our parasitic targets
set_target_properties(qux PROPERTIES LINKER_LANGUAGE CXX)

target_compile_definitions(qux PUBLIC TARGET_PUB_FOO=2)
target_compile_definitions(qux INTERFACE TARGET_IF_FOO=3)

target_include_directories(qux 
  PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/../include")


# attachments on first target

attach_llvmir_target(qux_bc qux)

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


