cmake_minimum_required(VERSION 3.16)
project(SDLSceneSmoke LANGUAGES C OBJC)

set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
add_subdirectory(../.. SDL)
add_executable(SDLSceneSmoke MACOSX_BUNDLE main.m)
target_compile_options(SDLSceneSmoke PRIVATE -fobjc-arc)
target_link_libraries(SDLSceneSmoke PRIVATE SDL3::SDL3-static)
set_target_properties(SDLSceneSmoke PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist")
