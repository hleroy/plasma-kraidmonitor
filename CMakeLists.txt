cmake_minimum_required(VERSION 3.16)

project(plasma-kraidmonitor)

# Make sure we're using Qt6
set(QT_MAJOR_VERSION 6)
set(QT_MIN_VERSION "6.5.0")

find_package(ECM 1.4.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

# Find Qt6 packages first
find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Qml
)

# Then find Plasma
find_package(Plasma REQUIRED)

# Find KF6
find_package(KF6 REQUIRED COMPONENTS
    I18n
)

set(kraidmonitor_SRCS
    plugin/kraidmonitor.cpp
)

add_library(kraidmonitorplugin SHARED ${kraidmonitor_SRCS})

target_link_libraries(kraidmonitorplugin
    Qt6::Core
    Qt6::Qml
    KF6::I18n
)

install(TARGETS kraidmonitorplugin DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/private/kraidmonitor)
install(FILES plugin/qmldir DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/private/kraidmonitor)

plasma_install_package(package org.kde.plasma.kraidmonitor)

# Install icons
install(FILES package/contents/icons/raidgreen.svg
              package/contents/icons/raidred.svg
              package/contents/icons/raidyellow.svg
        DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/org.kde.plasma.kraidmonitor/contents/icons)

# Translations
ki18n_install(po)
