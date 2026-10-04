#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "googleloginhelper.h"
#include "googleplayapi.h"
#include "versionmanager.h"
#include "apkextractiontask.h"
#include "googleapkdownloadtask.h"
#include "googleversionchannel.h"
#include "gamelauncher.h"
#include "profilemanager.h"
#include "qmlurlutils.h"
#include "launchersettings.h"
#include "launcherapp.h"
#include "troubleshooter.h"
#include "updatechecker.h"
#include "modmanager.h"
#include "lumenconfig.h"
#include "lumenprofiles.h"
#include "zipextractiontask.h"
#include "downloadtask.h"

#include <QTranslator>
#include <QCommandLineParser>
#include <QCommandLineOption>
#include <curl/curl.h>
#include <QObject>
#include <QCoreApplication>
#include <QtConcurrent>
#include "gamepad.h"
#ifdef LAUNCHER_ENABLE_GLFW
#include <QTimer>
#include <QQuickWindow>
#include <QMouseEvent>
#include <QProcess>
#include <QIcon>
#include <QKeyEvent>
#include <QWindow>
#include <GLFW/glfw3.h>
#endif
#include <fstream>
#include <sstream>
#include <mcpelauncher/path_helper.h>
#include "encryption.h"
#include "stdio_helper.h"
#include "updatemanager.h"
#include "crash_handler.h"

#ifdef LAUNCHER_DISABLE_DEV_MODE
bool LauncherSettings::disableDevMode = 1;
#else
bool LauncherSettings::disableDevMode = 0;
#endif

#ifdef GOOGLEPLAYDOWNLOADER_USEQT
Q_DECLARE_METATYPE(playapi::proto::finsky::download::AndroidAppDeliveryData)
#endif

int main(int argc, char *argv[])
{
    bool isSafeMode = getenv("SAFE_MODE") != nullptr;
    CrashHandler::registerCrashHandler(argc, argv);
#ifdef LAUNCHER_INIT_PATCH
    LAUNCHER_INIT_PATCH
#endif
    curl_global_init(CURL_GLOBAL_ALL);
    Q_INIT_RESOURCE(googlesigninui);
    QCoreApplication::setOrganizationName("Minecraft Linux Launcher");
    QCoreApplication::setOrganizationDomain("mrarm.io");
    QCoreApplication::setApplicationName("Minecraft Linux Launcher UI");

    LauncherApp app(argc, argv);
    app.setWindowIcon(QIcon(":/Resources/lumen-icon.svg"));
    QGuiApplication::setDesktopFileName("lumen-launcher");
    QTranslator translator;
    if (translator.load(QLocale(), QLatin1String("mcpelauncher"), QLatin1String("_"), QLatin1String(":/translations"))) {
        app.installTranslator(&translator);
    }
#ifndef NDEBUG
    else {
        qDebug() << "cannot load translator " << QLocale().name() << " check content of translations.qrc";
    }
#endif

    QCommandLineParser parser;
    parser.setApplicationDescription("Lumen Launcher");
    parser.addPositionalArgument("file", "file or uri to open with the default profile");
    parser.addHelpOption();
    QCommandLineOption devmodeOption(QStringList() << "d" << "enable-devmode", 
        QCoreApplication::translate("main", "Developer Mode - Enable unsafe Launcher Settings"));
    parser.addOption(devmodeOption);

    QCommandLineOption verboseOption(QStringList() << "v" << "verbose", 
        QCoreApplication::translate("main", "Verbose log Qt Messages to stdout"));
    parser.addOption(verboseOption);

    QCommandLineOption profileOption(QStringList() << "p" << "profile", 
        QCoreApplication::translate("main", "directly start the game launcher with the specified profile"), "profileName", "");
    parser.addOption(profileOption);

    QCommandLineOption requestGoogleCredentialsOption(QStringList() << "request-google-credentials", 
        QCoreApplication::translate("main", "Request Google Play Services credentials"));
    parser.addOption(requestGoogleCredentialsOption);

    QCommandLineOption modOption(QStringList() << "mod", 
        QCoreApplication::translate("main", "The mod requesting Google Play Services credentials"), "modPath", "");
    parser.addOption(modOption);

    parser.process(app);
    
    bool hasFileOrUri = parser.positionalArguments().count() == 1;

    if(parser.isSet(profileOption) || hasFileOrUri) {
        return app.launchProfileFile(parser.value(profileOption), hasFileOrUri ? parser.positionalArguments().at(0) : "");
    }

    auto verbose = parser.isSet(verboseOption);

    if(qEnvironmentVariableIsSet("LUMEN_DEBUG")) {
        qInstallMessageHandler([](QtMsgType, const QMessageLogContext &, const QString &msg) {
            fprintf(stderr, "%s\n", msg.toLocal8Bit().constData());
        });
    } else if(!verbose) {
        // Silence console
        qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &context, const QString &msg) {});
    }

    app.setQuitOnLastWindowClosed(false);
#ifdef GOOGLEPLAYDOWNLOADER_USEQT
    qRegisterMetaType<playapi::proto::finsky::download::AndroidAppDeliveryData>();
#endif
    qmlRegisterType<GoogleAccount>("io.mrarm.mcpelauncher", 1, 0, "GoogleAccount");
    qmlRegisterType<GoogleLoginHelper>("io.mrarm.mcpelauncher", 1, 0, "GoogleLoginHelper");
    qmlRegisterType<GooglePlayApi>("io.mrarm.mcpelauncher", 1, 0, "GooglePlayApi");
    qmlRegisterType<VersionInfo>("io.mrarm.mcpelauncher", 1, 0, "VersionInfo");
    qmlRegisterType<VersionManager>("io.mrarm.mcpelauncher", 1, 0, "VersionManager");
    qmlRegisterType<ApkExtractionTask>("io.mrarm.mcpelauncher", 1, 0, "ApkExtractionTask");
    qmlRegisterType<GoogleApkDownloadTask>("io.mrarm.mcpelauncher", 1, 0, "GoogleApkDownloadTask");
    qmlRegisterType<GoogleVersionChannel>("io.mrarm.mcpelauncher", 1, 0, "GoogleVersionChannel");
    qmlRegisterType<GameLauncher>("io.mrarm.mcpelauncher", 1, 0, "GameLauncher");
    qmlRegisterType<ProfileManager>("io.mrarm.mcpelauncher", 1, 0, "ProfileManager");
    qmlRegisterType<ProfileInfo>("io.mrarm.mcpelauncher", 1, 0, "ProfileInfo");
    qmlRegisterType<ArchivalVersionInfo>("io.mrarm.mcpelauncher", 1, 0, "ArchivalVersionInfo");
    qmlRegisterType<LauncherSettings>("io.mrarm.mcpelauncher", 1, 0, "LauncherSettings");
    qmlRegisterType<Troubleshooter>("io.mrarm.mcpelauncher", 1, 0, "Troubleshooter");
    qmlRegisterType<UpdateChecker>("io.mrarm.mcpelauncher", 1, 0, "UpdateChecker");
    qmlRegisterSingletonType<QmlUrlUtils>("io.mrarm.mcpelauncher", 1, 0, "QmlUrlUtils", &QmlUrlUtils::createInstance);
    static GamepadManager* gamepadManager = new GamepadManager();
    qmlRegisterSingletonType<GamepadManager>("io.mrarm.mcpelauncher", 1, 0, "GamepadManager", +[](QQmlEngine*, QJSEngine*) -> QObject* {
        return gamepadManager;
    });
    qRegisterMetaType<ModInfo>("ModInfo");
    qmlRegisterType<ModManager>("io.mrarm.mcpelauncher", 1, 0, "ModManager");
    qmlRegisterType<LumenConfig>("io.mrarm.mcpelauncher", 1, 0, "LumenConfig");
    qmlRegisterType<LumenProfiles>("io.mrarm.mcpelauncher", 1, 0, "LumenProfiles");
    qmlRegisterType<ZipExtractionTask>("io.mrarm.mcpelauncher", 1, 0, "ZipExtractionTask");
    qmlRegisterType<DownloadTask>("io.mrarm.mcpelauncher", 1, 0, "DownloadTask");
    qmlRegisterType<DownloadDataWrapper>("io.mrarm.mcpelauncher", 1, 0, "DownloadDataWrapper");
    qmlRegisterType<StdioHelper>("io.mrarm.mcpelauncher", 1, 0, "StdioHelper");
    qmlRegisterType<UpdateManager>("io.mrarm.mcpelauncher", 1, 0, "UpdateManager");
    QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)).mkpath("mcpelauncher/background_art");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("application", &app);
#ifdef LAUNCHER_VERSION_NAME
    engine.rootContext()->setContextProperty("LAUNCHER_VERSION_NAME", QVariant(LAUNCHER_VERSION_NAME));
#else
    engine.rootContext()->setContextProperty("LAUNCHER_VERSION_NAME", QVariant(""));
#endif
#ifdef LAUNCHER_FLATPAK_CONFIG_URL
    engine.rootContext()->setContextProperty("LAUNCHER_FLATPAK_CONFIG_URL", QVariant(LAUNCHER_FLATPAK_CONFIG_URL));
#else
    engine.rootContext()->setContextProperty("LAUNCHER_FLATPAK_CONFIG_URL", QVariant(""));
#endif
#ifdef LAUNCHER_VERSION_CODE
    engine.rootContext()->setContextProperty("LAUNCHER_VERSION_CODE", QVariant(LAUNCHER_VERSION_CODE));
#else
    engine.rootContext()->setContextProperty("LAUNCHER_VERSION_CODE", QVariant(0));
#endif
#ifdef LAUNCHER_VERSION_COMPAT
    engine.rootContext()->setContextProperty("LAUNCHER_VERSION_COMPAT", QVariant(LAUNCHER_VERSION_COMPAT));
#else
    engine.rootContext()->setContextProperty("LAUNCHER_VERSION_COMPAT", QVariant(0));
#endif
    QString license;
    QFile lfile(":/LICENSE");
    if(lfile.open(QIODevice::ReadOnly)) {
        license = lfile.readAll();
        lfile.close();
    }
#ifdef LAUNCHER_CHANGE_LOG
    engine.rootContext()->setContextProperty("LAUNCHER_CHANGE_LOG", QVariant(QString(LAUNCHER_CHANGE_LOG) + "\n" + license.replace("\n", "<br/>")));
#else
    engine.rootContext()->setContextProperty("LAUNCHER_CHANGE_LOG", QVariant(QString("Lumen Launcher is a modified version of the Minecraft Linux Launcher (minecraft-linux, maintained by ChristopherHX and contributors) and is free software under the GNU GPL v3. Source: github.com/minecraft-linux/mcpelauncher-ui-manifest<br/><br/>The game engine comes from the flatpak io.mrarm.mcpelauncher; Lumen keeps your game, worlds and settings in ~/Lumen.<br/><br/>") + license.replace("\n", "<br/>")));
#endif
#ifdef LAUNCHER_ENABLE_GOOGLE_PLAY_LICENCE_CHECK
    engine.rootContext()->setContextProperty("LAUNCHER_ENABLE_GOOGLE_PLAY_LICENCE_CHECK", QVariant(true));
#else
    engine.rootContext()->setContextProperty("LAUNCHER_ENABLE_GOOGLE_PLAY_LICENCE_CHECK", QVariant(false));
#endif
#ifdef __APPLE__
    engine.rootContext()->setContextProperty("SHOW_ANGLEBACKEND", QVariant(true));
#else
    engine.rootContext()->setContextProperty("SHOW_ANGLEBACKEND", QVariant(false));
#endif
    engine.rootContext()->setContextProperty("DISABLE_DEV_MODE", QVariant(LauncherSettings::disableDevMode &= !parser.isSet(devmodeOption)));

    engine.rootContext()->setContextProperty("SOURCE_MOD", QVariant(parser.isSet(modOption) ? parser.value(modOption) : ""));
    engine.rootContext()->setContextProperty("SAFE_MODE", QVariant(isSafeMode));

    // Test hooks (headless screenshots): LUMEN_START_PAGE=<sidebar index>, LUMEN_SCREENSHOT=<png path>
    engine.rootContext()->setContextProperty("LUMEN_START_PAGE", qEnvironmentVariableIntValue("LUMEN_START_PAGE", nullptr) );
    engine.rootContext()->setContextProperty("LUMEN_START_SET", qEnvironmentVariableIsSet("LUMEN_START_PAGE"));
    engine.load(QUrl(parser.isSet(requestGoogleCredentialsOption) ? QStringLiteral("qrc:/qml/RequestGoogleCredentials.qml") : QStringLiteral("qrc:/qml/main.qml")));
    if (!engine.rootObjects().isEmpty() && qEnvironmentVariableIsSet("LUMEN_TEST_DRAG")) {
        // headless test: LUMEN_TEST_DRAG="x1,y1,x2,y2" presses at (x1,y1), drags to (x2,y2) and releases
        QTimer::singleShot(7500, &app, [&engine]() {
            auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            auto parts = qEnvironmentVariable("LUMEN_TEST_DRAG").split(',');
            if (!w || parts.size() != 4)
                return;
            QPointF a(parts[0].toDouble(), parts[1].toDouble()), b(parts[2].toDouble(), parts[3].toDouble());
            auto send = [w](QEvent::Type t, QPointF p, Qt::MouseButton btn, Qt::MouseButtons btns) {
                QMouseEvent ev(t, p, w->mapToGlobal(p), btn, btns, Qt::NoModifier);
                QCoreApplication::sendEvent(w, &ev);
            };
            send(QEvent::MouseMove, a, Qt::NoButton, Qt::NoButton);
            send(QEvent::MouseButtonPress, a, Qt::LeftButton, Qt::LeftButton);
            for (int i = 1; i <= 10; i++)
                send(QEvent::MouseMove, a + (b - a) * (i / 10.0), Qt::NoButton, Qt::LeftButton);
            send(QEvent::MouseButtonRelease, b, Qt::LeftButton, Qt::NoButton);
        });
    }
    if (!engine.rootObjects().isEmpty() && qEnvironmentVariableIsSet("LUMEN_SCREENSHOT")) {
        QTimer::singleShot(qEnvironmentVariableIntValue("LUMEN_SCREENSHOT_MS") > 0 ? qEnvironmentVariableIntValue("LUMEN_SCREENSHOT_MS") : 6000, &app, [&engine, &app]() {
            if (auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first()))
                w->grabWindow().save(qEnvironmentVariable("LUMEN_SCREENSHOT"));
            app.quit();
        });
    }
    if (!engine.rootObjects().isEmpty() && qEnvironmentVariableIsSet("HYPRLAND_INSTANCE_SIGNATURE")) {
        // Keep the window floating (it is no longer fixed-size, so a tiling WM would tile it) and centred.
        QTimer::singleShot(350, []() {
            QProcess::startDetached("sh", QStringList() << "-c" <<
                "hyprctl dispatch \"hl.dsp.window.float({action='enable', window='title:^Lumen Launcher$'})\" >/dev/null 2>&1; "
                "hyprctl dispatch \"hl.dsp.window.center({window='title:^Lumen Launcher$'})\" >/dev/null 2>&1 || "
                "(hyprctl dispatch focuswindow 'title:^Lumen Launcher$' && hyprctl dispatch setfloating && hyprctl dispatch centerwindow) >/dev/null 2>&1");
        });
    }
    if (engine.rootObjects().isEmpty())
        return -1;

    if(!parser.isSet(requestGoogleCredentialsOption) && !isSafeMode) {
#ifdef LAUNCHER_ENABLE_GLFW
    glfwInitHint(GLFW_JOYSTICK_HAT_BUTTONS, GLFW_FALSE);
    std::vector<std::string> controllerDbPaths;
    PathHelper::findAllDataFiles("gamecontrollerdb.txt", [&controllerDbPaths](std::string const& path) {
        controllerDbPaths.push_back(path);
    });
    // Bugfix: allow users to change internal gamepad layouts
    std::reverse(controllerDbPaths.begin(), controllerDbPaths.end());
    for(std::string const& path : controllerDbPaths) {
        printf("Loading gamepad mappings: %s\n", path.c_str());
        std::ifstream mapping(path.data(), std::ios::binary);
        if(mapping.is_open()) {
            std::stringstream file;
            file << mapping.rdbuf();
            glfwUpdateGamepadMappings(file.str().data());
        }
    }
    QTimer *timer = new QTimer(&app);
    GLFWgamepadstate oldstate;
    memset(&oldstate, 0, sizeof(oldstate));
    auto addRemoveGamePad = +[](int jid, int event) {
        if(event == GLFW_CONNECTED) {
            auto guid = glfwGetJoystickGUID(jid);
            auto name = glfwGetJoystickName(jid);
            int axescount, hatscount, buttonscount;
            if (!glfwGetJoystickAxes(jid, &axescount)) {
                axescount = 0;
            }
            if (!glfwGetJoystickHats(jid, &hatscount)) {
                hatscount = 0;
            }
            if (!glfwGetJoystickButtons(jid, &buttonscount)) {
                buttonscount = 0;
            }
            std::ostringstream mapping;
            mapping << guid << "," << name;
            const char* btns[] = { "a", "b", "x", "y", "leftshoulder", "rightshoulder", "righttrigger", "lefttrigger", "back", "start", "leftstick", "rightstick", "guide", "dpleft", "dpdown", "dpright", "dpup" };
            const char* axes[] = { "leftx", "lefty", "rightx", "righty", "lefttrigger", "righttrigger" };
            if (axescount) {
                std::ostringstream submap;
                for (size_t i = 0; i < axescount && i < sizeof(axes) / sizeof(axes[0]); i++) {
                    submap << "," << axes[i] << ":a" << i;
                }
                mapping << submap.str();
            }
            const char* hats[] = { "dpup", "dpright", "dpdown", "dpleft" };
            if (hatscount) {
                std::ostringstream submap;
                for (size_t i = 0; i < hatscount && i < sizeof(hats) / sizeof(hats[0]) / 4; i++) {
                   for (size_t j = 0; j < 4; j++) {
                       submap << "," << hats[i*4 + j] << ":h" << i << "." << (1 << j);
                   }
                }
                mapping << submap.str();
            }
            if (buttonscount) {
                std::ostringstream submap;
                for (size_t i = 0; i < buttonscount && i < sizeof(btns) / sizeof(btns[0]); i++) {
                    submap << "," << btns[i] << ":b" << i;
                }
                mapping << submap.str();
            }
            auto mapstr = mapping.str();
            mapstr = mapstr + ",platform:Linux,\n" + mapstr + ",platform:Mac OS X,";
            auto gamepad = new Gamepad(gamepadManager, jid, guid, name, QString::fromStdString(mapstr));
            glfwSetJoystickUserPointer(jid, gamepad);
            ((Gamepad*)gamepad)->setHasMapping(glfwJoystickIsGamepad(jid));
            gamepadManager->gamepads().append(gamepad);
        } else {
            auto gamepad = (Gamepad*)glfwGetJoystickUserPointer(jid);
            gamepadManager->gamepads().removeOne(gamepad);
        }
        gamepadManager->gamepadsChanged();
    };
    glfwSetJoystickCallback(addRemoveGamePad);
    for(int i = GLFW_JOYSTICK_1; i < GLFW_JOYSTICK_LAST; i++) {
        if(glfwJoystickPresent(i)) {
            addRemoveGamePad(i, GLFW_CONNECTED);
        }
    }
    bool glfwNeedsInit = true;
    QObject::connect(timer, &QTimer::timeout, [&]() {
        // qt6.7 macOS app does not close workaround
        bool hasVisibleWindow = false;
        for(auto&& window : QGuiApplication::topLevelWindows()) {
            if(window->isVisible()) {
                hasVisibleWindow = true;
                break;
            }
        }
        if(!hasVisibleWindow && !gamepadManager->gameRunning()) {
            if(!glfwNeedsInit) {
                glfwTerminate();
                glfwNeedsInit = true;
            }
            app.quit();
            return;
        }
        if(!hasVisibleWindow) {
            return; // No windows, no need to poll events
        }
        if(glfwNeedsInit) {
            glfwInit();
            glfwNeedsInit = false;
        }
        glfwPollEvents();
        if(gamepadManager->enabled()) {
            for(auto&& gamepad : gamepadManager->gamepads()) {
                GLFWgamepadstate state;
                if(glfwGetGamepadState(((Gamepad*)gamepad)->id(), &state) == GLFW_TRUE) {
                    QObject* window = QGuiApplication::focusWindow();
                    if(window) {
                        if(oldstate.buttons[GLFW_GAMEPAD_BUTTON_A] != state.buttons[GLFW_GAMEPAD_BUTTON_A]) {
                            QCoreApplication::postEvent(window, new QKeyEvent(state.buttons[GLFW_GAMEPAD_BUTTON_A] ? QEvent::Type::KeyPress : QEvent::Type::KeyRelease, Qt::Key_Space, Qt::NoModifier), Qt::NormalEventPriority);
                        }
                        if(oldstate.buttons[GLFW_GAMEPAD_BUTTON_B] != state.buttons[GLFW_GAMEPAD_BUTTON_B]) {
                            QCoreApplication::postEvent(window, new QKeyEvent(state.buttons[GLFW_GAMEPAD_BUTTON_B] ? QEvent::Type::KeyPress : QEvent::Type::KeyRelease, Qt::Key_Escape, Qt::NoModifier), Qt::NormalEventPriority);
                        }
                        if(oldstate.buttons[GLFW_GAMEPAD_BUTTON_DPAD_LEFT] != state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_LEFT]) {
                            QCoreApplication::postEvent(window, new QKeyEvent(state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_LEFT] ? QEvent::Type::KeyPress : QEvent::Type::KeyRelease, Qt::Key_Backtab, Qt::NoModifier), Qt::NormalEventPriority);
                        }
                        if(oldstate.buttons[GLFW_GAMEPAD_BUTTON_DPAD_RIGHT] != state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_RIGHT]) {
                            QCoreApplication::postEvent(window, new QKeyEvent(state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_RIGHT] ? QEvent::Type::KeyPress : QEvent::Type::KeyRelease, Qt::Key_Tab, Qt::NoModifier), Qt::NormalEventPriority);
                        }
                        if(oldstate.buttons[GLFW_GAMEPAD_BUTTON_DPAD_DOWN] != state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_DOWN]) {
                            QCoreApplication::postEvent(window, new QKeyEvent(state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_DOWN] ? QEvent::Type::KeyPress : QEvent::Type::KeyRelease, Qt::Key_Down, Qt::NoModifier), Qt::NormalEventPriority);
                        }
                        if(oldstate.buttons[GLFW_GAMEPAD_BUTTON_DPAD_UP] != state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_UP]) {
                            QCoreApplication::postEvent(window, new QKeyEvent(state.buttons[GLFW_GAMEPAD_BUTTON_DPAD_UP] ? QEvent::Type::KeyPress : QEvent::Type::KeyRelease, Qt::Key_Up, Qt::NoModifier), Qt::NormalEventPriority);
                        }
                        oldstate = state;
                    }
                }
            }
        }
        for(auto&& gamepad : gamepadManager->gamepads()) {
            auto joystick = ((Gamepad*)gamepad)->id();
            int axesCount, hatsCount, buttonsCount;
            auto axes = glfwGetJoystickAxes(joystick, &axesCount);  
            auto hats = glfwGetJoystickHats(joystick, &hatsCount);
            auto buttons = glfwGetJoystickButtons(joystick, &buttonsCount);
            ((Gamepad*)gamepad)->updateInput(buttons, buttonsCount, hats, hatsCount, axes, axesCount);
            ((Gamepad*)gamepad)->setHasMapping(glfwJoystickIsGamepad(joystick));
        }
    });
    timer->setInterval(50);
    timer->start();
#endif
    }

    return app.exec();
}
