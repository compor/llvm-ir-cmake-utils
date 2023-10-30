# cmake file

cmake_minimum_required(VERSION 3.9)

find_program(CMAKE_C_COMPILER clang)
find_program(CMAKE_CXX_COMPILER clang++)

project(staticlib)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake")

message(STATUS ${CMAKE_MODULE_PATH})
include(LLVMIRUtil)

add_subdirectory(staticlib)
add_subdirectory(executable)

