add_executable(main main.c)
target_include_directories(main PUBLIC "./../staticlib/include")
target_link_libraries(main "${CMAKE_BINARY_DIR}/staticlib/libtestlib_instrumented.a")
