# cmake file

cmake_minimum_required(VERSION 3.2)

project(qux C CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake")

message(STATUS ${CMAKE_MODULE_PATH})
include(LLVMIRUtil)

add_subdirectory(src)

