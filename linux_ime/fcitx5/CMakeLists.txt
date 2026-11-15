cmake_minimum_required(VERSION 3.21)
project(telexmini_fcitx5 VERSION 2.4.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(GNUInstallDirs)
find_package(Fcitx5Core REQUIRED)
add_library(telexmini SHARED
  telexmini.cpp
  ../../native_core/core.cpp
  ../../native_core/c_api.cpp)
target_include_directories(telexmini PRIVATE ../../native_core)
target_link_libraries(telexmini PRIVATE Fcitx5::Core)
target_compile_definitions(telexmini PRIVATE
  TELEXMINI_SEED_PATH="${CMAKE_INSTALL_FULL_DATADIR}/telexmini/english-core.txt")
# Fcitx5 resolves Library=telexmini as libtelexmini.so; retain the lib prefix.
install(TARGETS telexmini DESTINATION "${CMAKE_INSTALL_LIBDIR}/fcitx5")
install(FILES telexmini-addon.conf RENAME telexmini.conf DESTINATION "${CMAKE_INSTALL_DATADIR}/fcitx5/addon")
install(FILES telexmini.conf DESTINATION "${CMAKE_INSTALL_DATADIR}/fcitx5/inputmethod")
install(FILES ../../Resources/english-core.txt DESTINATION "${CMAKE_INSTALL_DATADIR}/telexmini")
