# cmake file

# options

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0")

set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-rpath /lib")

# general defs

set(SOURCES
  bar.cpp)


# directory level


# target level

add_library(bar ${SOURCES})

# this property is required by our parasitic targets
set_target_properties(bar PROPERTIES LINKER_LANGUAGE CXX)

target_include_directories(bar PUBLIC 
  "${CMAKE_CURRENT_SOURCE_DIR}/../include")


# attachments on first target

attach_llvmir_bc_target(bar_bc bar)

attach_llvmir_opt_pass_target(bar_pass1 bar_bc -mem2reg)
attach_llvmir_opt_pass_target(bar_pass2 bar_pass1 -simplifycfg -licm)
attach_llvmir_opt_pass_target(bar_pass3 bar_pass2 -licm)

attach_llvmir_disassemble_target(bar_dis bar_pass2)
attach_llvmir_assemble_target(bar_as bar_dis)

attach_llvmir_link_target(bar_llvmlink bar_pass2)

attach_llvmir_opt_pass_target(bar_pass4 bar_llvmlink -simplifycfg)

attach_llvmir_library(bar_bc_lib bar_pass2 SHARED)


