set(CMAKE_BUILD_TYPE Debug)
# set(LLVM_PASS_PLUGIN "<filepath to llvm plugin pass>")

set(SOURCE_FILES
  src/Test1.c
  src/Test2.c
  src/Test3.c
)

add_library(testlib STATIC ${SOURCE_FILES})
target_include_directories(testlib PUBLIC "./include")
set_target_properties(testlib PROPERTIES LINKER_LANGUAGE C)

llvmir_attach_bc_target(testlib_bc testlib)
llvmir_attach_opt_pass_target(testlib_opt testlib_bc) # -load-pass-plugin=${LLVM_PASS_PLUGIN} -passes=ctrace)

llvmir_attach_obj_target(testlib_obj testlib_opt)
llvmir_attach_library(testlib_instrumented testlib_obj STATIC)
