project(domlogo)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 14)

find_package(Qt5Widgets)
find_package(Qt5Quick)

add_executable(domlogo main.cc logthread.cc domlogo.qrc teams.qrc)

target_link_libraries(domlogo Qt5::Widgets Qt5::Quick)
