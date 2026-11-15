cmake_minimum_required(VERSION 3.21)
project(telexmini_ibus VERSION 2.4.0 LANGUAGES C CXX)
include(GNUInstallDirs)
set(CMAKE_CXX_STANDARD 20)
find_package(PkgConfig REQUIRED)
pkg_check_modules(IBUS REQUIRED IMPORTED_TARGET ibus-1.0)
add_executable(telexmini-ibus
  ibus_engine.c
  ../../native_core/core.cpp
  ../../native_core/c_api.cpp)
target_include_directories(telexmini-ibus PRIVATE ../../native_core)
target_link_libraries(telexmini-ibus PRIVATE PkgConfig::IBUS)
target_compile_definitions(telexmini-ibus PRIVATE
  TELEXMINI_SEED_PATH="${CMAKE_INSTALL_FULL_DATADIR}/telexmini/english-core.txt")
configure_file(telexmini.xml.in telexmini.xml @ONLY)
install(TARGETS telexmini-ibus DESTINATION "${CMAKE_INSTALL_LIBEXECDIR}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/telexmini.xml"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/ibus/component")
install(FILES ../../Resources/english-core.txt DESTINATION "${CMAKE_INSTALL_DATADIR}/telexmini")
