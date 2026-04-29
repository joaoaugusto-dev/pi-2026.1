cmake_minimum_required(VERSION 3.10)
project(vision_engine)

# Resolve o OpenCV Android SDK sem depender de caminho absoluto da maquina.
set(_opencv_sdk_jni_dir "${CMAKE_CURRENT_LIST_DIR}/../OpenCV-android-sdk/sdk/native/jni")

if(DEFINED ENV{OpenCV_DIR} AND NOT "$ENV{OpenCV_DIR}" STREQUAL "")
    set(OpenCV_DIR "$ENV{OpenCV_DIR}")
elseif(EXISTS "${_opencv_sdk_jni_dir}")
    set(OpenCV_DIR "${_opencv_sdk_jni_dir}")
else()
    message(FATAL_ERROR
        "OpenCV Android SDK nao encontrado. "
        "Defina a variavel de ambiente OpenCV_DIR ou adicione o SDK em "
        "${_opencv_sdk_jni_dir}"
    )
endif()

find_package(OpenCV REQUIRED)

add_library(vision_engine SHARED vision_engine.cpp drawing_utils.cpp)

target_compile_features(vision_engine PRIVATE cxx_std_17)
target_compile_options(
    vision_engine
    PRIVATE
    $<$<CONFIG:Release>:-O3>
)

target_link_libraries(vision_engine ${OpenCV_LIBS})
