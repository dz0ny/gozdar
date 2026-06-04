# mwm_dump — built INSIDE an organicmaps checkout (see build.sh).
#
# build.sh copies this folder to <organicmaps>/mwm_dump/ and appends
#   add_subdirectory(mwm_dump)
# to the root CMakeLists.txt.
#
# Linking just `generator` mirrors generator/generator_tool and transitively
# pulls indexer/coding/geometry/platform/editor/base — everything mwm_dump.cpp
# needs (feature reading, classificator, geometry decode).

project(mwm_dump)

omim_add_executable(${PROJECT_NAME} mwm_dump.cpp)

target_link_libraries(${PROJECT_NAME} PRIVATE generator)
