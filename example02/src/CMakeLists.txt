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

if(CMAKE_VERSION VERSION_EQUAL "3.1" OR CMAKE_VERSION VERSION_GREATER "3.1")
  set_property(TARGET bar PROPERTY CXX_STANDARD 11)
endif()

# attachments on first target

llvmir_attach_bc_target(bar_bc bar)

llvmir_attach_opt_pass_target(bar_pass1 bar_bc -mem2reg)
llvmir_attach_opt_pass_target(bar_pass2 bar_pass1 -simplifycfg -licm)
llvmir_attach_opt_pass_target(bar_pass3 bar_pass2 -licm)

llvmir_attach_disassemble_target(bar_dis bar_pass2)
llvmir_attach_assemble_target(bar_as bar_dis)

llvmir_attach_link_target(bar_llvmlink bar_pass2)

llvmir_attach_opt_pass_target(bar_pass4 bar_llvmlink -simplifycfg)

llvmir_attach_library(bar_bc_lib bar_pass2 SHARED)


