cmake_minimum_required(VERSION 3.16)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(voo_benchmark LANGUAGES CXX)
endif()

find_package(TCL QUIET)

if(NOT TCL_LIBRARY OR NOT TCL_INCLUDE_PATH)
    # Search common TCL installation locations
    find_path(VOO_TCL_INCLUDE_DIR tcl.h
        PATHS /usr/include/tcl8.7 /usr/include/tcl8.6 /usr/include
        NO_DEFAULT_PATH
    )
    find_library(VOO_TCL_LIBRARY
        NAMES tcl8.7 tcl8.6 tcl
        PATHS /usr/lib /usr/lib/x86_64-linux-gnu /usr/local/lib
        NO_DEFAULT_PATH
    )
    if(NOT VOO_TCL_INCLUDE_DIR OR NOT VOO_TCL_LIBRARY)
        message(FATAL_ERROR "TCL development files not found. Install tcl-dev or libtcl-dev.")
    endif()
    set(TCL_INCLUDE_PATH "${VOO_TCL_INCLUDE_DIR}")
    set(TCL_LIBRARY "${VOO_TCL_LIBRARY}")
endif()

function(tclxx_link_tcl target)
    if(TARGET Tcl::Tcl)
        target_link_libraries(${target} PRIVATE Tcl::Tcl)
    elseif(TARGET TCL::TCL)
        target_link_libraries(${target} PRIVATE TCL::TCL)
    else()
        if(TCL_INCLUDE_PATH AND TCL_LIBRARY)
            target_include_directories(${target} PRIVATE ${TCL_INCLUDE_PATH})
            target_link_libraries(${target} PRIVATE ${TCL_LIBRARY})
        else()
            target_include_directories(${target} PRIVATE ${VOO_TCL_INCLUDE_DIR})
            target_link_libraries(${target} PRIVATE ${TCLXX_TCL_LIBRARY})
        endif()
    endif()
endfunction()

add_library(voopoint_pkg MODULE voo_point_pkg.cpp)
target_compile_features(voopoint_pkg PRIVATE cxx_std_17)
target_compile_options(voopoint_pkg PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/O2>
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-O3>
)

if(TARGET tclxx::tclxx)
    target_link_libraries(voopoint_pkg PRIVATE tclxx::tclxx)
else()
    target_include_directories(voopoint_pkg PRIVATE ${CMAKE_CURRENT_LIST_DIR}/../tclxx/include)
endif()

tclxx_link_tcl(voopoint_pkg)

set_target_properties(voopoint_pkg PROPERTIES
    PREFIX ""
    OUTPUT_NAME "voopoint_pkg"
)
