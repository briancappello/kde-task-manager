cmake_minimum_required(VERSION 3.16)
project(plasma-taskmanager-applet)

set(PROJECT_VERSION "6.6.0")
set(QT_MIN_VERSION "6.10.0")
set(KF6_MIN_VERSION "6.22.0")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQtDeclareLoggingCategory)
include(ECMQmlModule)
include(FeatureSummary)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS Core Qml Quick)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Config
    I18n
    KIO
    Notifications
    Service
    WindowSystem
)

find_package(Plasma REQUIRED)
find_package(PlasmaActivities REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
find_package(KSysGuard REQUIRED)
find_package(LibNotificationManager REQUIRED)

add_definitions(-DTRANSLATION_DOMAIN="plasma_applet_org.kde.plasma.taskmanager")

plasma_add_applet(org.kde.plasma.taskmanager
    QML_SOURCES
        qml/AudioStream.qml
        qml/Badge.qml
        qml/ConfigAppearance.qml
        qml/ConfigBehavior.qml
        qml/config.qml
        qml/ContextMenu.qml
        qml/GroupDialog.qml
        qml/GroupExpanderOverlay.qml
        qml/main.qml
        qml/MouseHandler.qml
        qml/PipeWireThumbnail.qml
        qml/PlayerController.qml
        qml/PulseAudio.qml
        qml/ScrollableTextWrapper.qml
        qml/TaskBadgeOverlay.qml
        qml/TaskList.qml
        qml/TaskProgressOverlay.qml
        qml/Task.qml
        qml/ToolTipDelegate.qml
        qml/ToolTipInstance.qml
        qml/ToolTipWindowMouseArea.qml
        qml/code/LayoutMetrics.js
        qml/code/TaskTools.js
    CPP_SOURCES
        backend.cpp
        smartlauncherbackend.cpp
        smartlauncheritem.cpp
    RESOURCES
        main.xml
    GENERATE_APPLET_CLASS
)

kconfig_add_kcfg_files(org.kde.plasma.taskmanager
    ${CMAKE_CURRENT_SOURCE_DIR}/kactivitymanagerd_plugins_settings.kcfgc)

ecm_qt_declare_logging_category(org.kde.plasma.taskmanager
    HEADER log_settings.h
    IDENTIFIER TASKMANAGER_DEBUG
    CATEGORY_NAME org.kde.plasma.taskmanager)

target_link_libraries(org.kde.plasma.taskmanager PRIVATE
    Qt::Core
    Qt::Qml
    Qt::Quick
    Plasma::Activities
    Plasma::ActivitiesStats
    KF6::ConfigGui
    KF6::I18n
    KF6::KIOCore
    KF6::KIOGui
    KF6::KIOFileWidgets
    KF6::Notifications
    Plasma::Plasma
    KSysGuard::ProcessCore
    KF6::Service
    KF6::WindowSystem
    PW::LibNotificationManager)
