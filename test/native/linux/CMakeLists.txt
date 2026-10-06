cmake_minimum_required(VERSION 3.18)
project(mpv_locale_test LANGUAGES CXX)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
find_program(XVFB_RUN xvfb-run REQUIRED)

add_executable(mpv_locale_test mpv_locale_test.cc)
target_compile_features(mpv_locale_test PRIVATE cxx_std_17)
target_compile_options(mpv_locale_test PRIVATE -Wall -Wextra -Werror -UNDEBUG)
target_include_directories(mpv_locale_test PRIVATE ../../../linux/runner)
target_link_libraries(mpv_locale_test PRIVATE PkgConfig::GTK PkgConfig::MPV)

enable_testing()
foreach(locale C C.UTF-8 en_US.UTF-8 zh_CN.UTF-8)
  add_test(NAME mpv_locale_${locale}
    COMMAND ${XVFB_RUN} -a $<TARGET_FILE:mpv_locale_test>)
  set_tests_properties(mpv_locale_${locale} PROPERTIES
    ENVIRONMENT "LANG=${locale};LC_ALL=${locale}" TIMEOUT 20)
endforeach()
