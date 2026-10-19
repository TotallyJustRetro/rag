cmake_minimum_required(VERSION 3.24)
project(rag LANGUAGES CXX)

option(RAG_BUILD_TESTS "Build RAG unit tests" ON)

add_library(rag_core
    src/gba_rom.cpp
    src/arm7tdmi.cpp
)
target_include_directories(rag_core PUBLIC include)
target_compile_features(rag_core PUBLIC cxx_std_20)

add_executable(rag src/main.cpp)
target_link_libraries(rag PRIVATE rag_core)

if(MSVC)
    target_compile_options(rag_core PRIVATE /W4 /permissive-)
    target_compile_options(rag PRIVATE /W4 /permissive-)
else()
    target_compile_options(rag_core PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(rag PRIVATE -Wall -Wextra -Wpedantic)
endif()

include(CTest)
if(BUILD_TESTING AND RAG_BUILD_TESTS)
    add_executable(rag_tests tests/test_core.cpp)
    target_link_libraries(rag_tests PRIVATE rag_core)
    if(MSVC)
        target_compile_options(rag_tests PRIVATE /W4 /permissive-)
    else()
        target_compile_options(rag_tests PRIVATE -Wall -Wextra -Wpedantic)
    endif()
    add_test(NAME rag_tests COMMAND rag_tests)

    add_executable(rag_save_backup_tests tools/test_save_backup.cpp)
    target_include_directories(rag_save_backup_tests PRIVATE tools)
    target_compile_features(rag_save_backup_tests PRIVATE cxx_std_20)
    if(MSVC)
        target_compile_options(rag_save_backup_tests PRIVATE /W4 /permissive-)
    else()
        target_compile_options(rag_save_backup_tests PRIVATE -Wall -Wextra -Wpedantic)
    endif()
    add_test(NAME rag_save_backup_tests COMMAND rag_save_backup_tests)
endif()
