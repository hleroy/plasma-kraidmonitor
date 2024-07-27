cmake_minimum_required(VERSION 3.16)

project(plasma-kraidmonitor)

set(QT_MIN_VERSION "5.15.0")
set(KF5_MIN_VERSION "5.92.0")

find_package(ECM ${KF5_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt5 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
)

find_package(KF5 ${KF5_MIN_VERSION} REQUIRED COMPONENTS
    Plasma
    I18n
    Service
    Package
    Declarative
)

set(kraidmonitor_SRCS
    plugin/kraidmonitor.cpp
)

add_library(kraidmonitorplugin SHARED ${kraidmonitor_SRCS})

target_link_libraries(kraidmonitorplugin
    Qt5::Core
    Qt5::Qml
    KF5::Plasma
    KF5::I18n
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
