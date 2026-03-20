cmake_minimum_required(VERSION 3.20)
project(vdt_core VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(vdt_core STATIC
  src/common/crc16.cpp
  src/common/bit_packing.cpp
  src/protocol/frame.cpp
  src/protocol/packet.cpp
  src/protocol/session.cpp
  src/encode/session_chunker.cpp
  src/encode/frame_encoder.cpp
  src/decode/frame_decoder.cpp
  src/decode/session_assembler.cpp
  src/render/layout.cpp
  src/vision/homography.cpp
  src/vision/grid_sampler.cpp
  src/vision/marker_detector.cpp
  src/capi.cpp
)

target_include_directories(vdt_core PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_compile_features(vdt_core PUBLIC cxx_std_20)

option(VDT_BUILD_TESTS "Build unit tests" ON)

if(VDT_BUILD_TESTS)
  include(FetchContent)
  FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.5.2
  )
  FetchContent_MakeAvailable(Catch2)

  add_executable(vdt_tests
    tests/test_crc16.cpp
    tests/test_encode_decode.cpp
    tests/test_frame_parse.cpp
    tests/test_symbol_mapping.cpp
  )
  target_link_libraries(vdt_tests PRIVATE vdt_core Catch2::Catch2WithMain)
  target_include_directories(vdt_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
  include(CTest)
  enable_testing()
  add_test(NAME vdt.core.unit COMMAND vdt_tests)
endif()
