import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Components"
import io.mrarm.mcpelauncher 1.0

ColumnLayout {
    id: page
    spacing: 0

    property var profileManager: profileManagerInstance // also read by ProfileComboBox
    property var googleLoginHelper: googleLoginHelperInstance // read by ProfileEditPopup
    property var versionManager: versionManagerInstance
    property var playVerChannel: playVerChannelInstance
    property string warnMessage: ""
    property string warnUrl: ""
    property var profile: profileManagerInstance.activeProfile
    property var installed: versionManagerInstance.versions.getAll().sort(function (a, b) {
        return b.versionCode - a.versionCode
    })
    // The profile's own pick, or (when it just follows "latest") the newest installed version
    property string currentDir: {
        if (profile && profile.versionType === ProfileInfo.LOCKED_NAME)
            return profile.versionDirName
        if (profile && profile.versionType === ProfileInfo.LOCKED_CODE) {
            for (var i = 0; i < installed.length; i++)
                if (installed[i].versionCode === profile.versionCode)
                    return installed[i].directory
        }
        return installed.length > 0 ? installed[0].directory : ""
    }
    // current version first, then the rest newest-first
    property var ordered: {
        var cur = [], rest = []
        for (var i = 0; i < installed.length; i++)
            (installed[i].directory === currentDir ? cur : rest).push(installed[i])
        return cur.concat(rest)
    }

    BaseHeader {
        title: qsTr("Versions")
    }

    ProfileEditPopup {
        id: profileEditPopup
        onAboutToHide: profileComboBox.onAddProfileResult(profileEditPopup.profile)
        versionManager: versionManagerInstance
        profileManager: profileManagerInstance
        playVerChannel: playVerChannelInstance
    }

    // Profile picker
    RowLayout {
        Layout.margins: 16
        Layout.bottomMargin: 4
        Layout.maximumHeight: 40
        spacing: 10
        Text {
            text: qsTr("PROFILE")
            color: "#e8b84a"
            font.pointSize: 9
            font.bold: true
            font.letterSpacing: 2
        }
        RowLayout {
            spacing: -1
            Layout.preferredHeight: 40
            Layout.maximumHeight: 40
            ProfileComboBox {
                property bool loaded: false
                id: profileComboBox
                Layout.preferredWidth: 200
                Layout.preferredHeight: 40
                onAddProfileSelected: {
                    profileEditPopup.reset()
                    profileEditPopup.open()
                }
                Component.onCompleted: {
                    setProfile(profileManagerInstance.activeProfile)
                    loaded = true
                }
                onCurrentProfileChanged: {
                    if (loaded && currentProfile !== null) {
                        profileManagerInstance.activeProfile = currentProfile
                    }
                }
                enabled: !gameLauncher.running
            }
            MButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                z: hovered ? 1 : -1
                Image {
                    anchors.centerIn: parent
                    source: "qrc:/Resources/icon-edit.png"
                    height: 20
                    width: 20
                    smooth: false
                    opacity: enabled ? 1.0 : 0.3
                }
                enabled: !gameLauncher.running
                onClicked: {
                    profileEditPopup.setProfile(profileComboBox.getProfile())
                    profileEditPopup.open()
                }
            }
        }
    }

    Text {
        Layout.margins: 16
        Layout.bottomMargin: 6
        text: qsTr("Pick the installed version the Play button launches.")
        color: "#9a8fd0"
        font.pointSize: 10
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.bottomMargin: 16
        spacing: 10
        clip: true
        enabled: !gameLauncher.running
        opacity: enabled ? 1 : 0.5
        model: page.ordered
        delegate: Rectangle {
            id: card
            required property var modelData
            required property int index
            property bool current: modelData.directory === page.currentDir
            width: ListView.view.width
            height: 64
            radius: 12
            color: current ? "#2d2459" : (cardMouse.containsMouse ? "#241c4a" : "#1c1638")
            border.width: 1
            border.color: current ? "#e8b84a" : "#3b3068"
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                spacing: 3
                Text {
                    text: modelData.directory
                    color: "#fff"
                    font.pointSize: 13
                    font.bold: parent.parent.current
                }
                Text {
                    text: parent.parent.current ? qsTr("Current version") : qsTr("Installed")
                    color: parent.parent.current ? "#e8b84a" : "#9a8fd0"
                    font.pointSize: 9
                }
            }
            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var prof = profileManagerInstance.activeProfile
                    // lock by version code, like the launcher's own profile editor does;
                    // a directory lock needs the "show unsupported/unverified" dev settings
                    prof.versionType = ProfileInfo.LOCKED_CODE
                    prof.versionCode = card.modelData.versionCode
                    prof.arch = card.modelData.archs.length > 0 ? card.modelData.archs[0] : ""
                    prof.save()
                }
            }
        }
    }

    // helpers ProfileEditPopup expects from its parent (same as HomeScreen)
    function adjustForChromeOSMode(latestVersion) {
        if(latestVersion && googleLoginHelper.chromeOS) {
            return {
                "versionName": latestVersion.versionName,
                "versionCode": 1000000000 + latestVersion.versionCode
            }
        }
        return latestVersion
    }

    function checkGooglePlayLatestSupport() {
        if (versionManager.availableArchivalVersions.length === 0) {
            console.log("Bug errata 1")
            page.warnMessage = qsTr("mcpelauncher-versiondb not loaded. Cannot check Minecraft version compatibility.")
            page.warnUrl = ""
            return true
        }

        if (launcherSettings.showUnsupported || versionManager.availableArchivalVersions.length === 0) {
            console.log("Bug errata 2")
            return true
        }

        // Handle latest is beta, beta isn't enabled
        if (playVerChannel.latestVersionIsBeta && !launcherSettings.showBetaVersions) {
            page.warnMessage = qsTr("Latest Minecraft Version %1 is a beta version, which is hidden by default.").arg(playVerChannel.latestVersion + (playVerChannel.latestVersionIsBeta ? " (beta)" : ""))
            page.warnUrl = "https://github.com/minecraft-linux/mcpelauncher-manifest/issues/797"
            return false
        }

        if (launcherSettings.showUnverified) {
            console.log("Bug errata 3")
            return true
        }

        if (checkRollForward(playVerChannel.latestVersionCode))
            return true

        const archiveInfo = findArchivalVersion(playVerChannel.latestVersionCode)
        if (archiveInfo !== null) {
            if (playVerChannel.latestVersionIsBeta && (launcherSettings.showBetaVersions || launcherSettings.showUnsupported) || !archiveInfo.isBeta) {
                if (googleLoginHelper.getAbis(launcherSettings.showUnsupported).includes(archiveInfo.abi)) {
                    page.warnMessage = ""
                    page.warnUrl = ""
                    return true
                }
            }
        }

        page.warnMessage = qsTr("Compatibility for latest Minecraft version %1 is unknown. Support for new Minecraft versions is a feature request.").arg(playVerChannel.latestVersion + (playVerChannel.latestVersionIsBeta ? " (beta)" : ""))
        page.warnUrl = "https://github.com/minecraft-linux/mcpelauncher-manifest/issues/797"
        return false
    }

    function checkRollForward(code) {
        return versionManager.archivalVersions.rollforwardVersionRange.some(range => range.minVersionCode <= code && code <= range.maxVersionCode)
    }

    function findArchivalVersion(code) {
        const versions = versionManager.availableArchivalVersions
        for (var i = versions.length - 1; i >= 0; --i) {
            if (versions[i].versionCode === code || versions[i].versionCode === (code - 1000000000))
                return versions[i]
        }
        return null
    }

    function getDisplayedNameForCode(code) {
        const suffix = code > 1000000000 ? qsTr(" (ChromeOS)") : launcherSettings.chromeOSMode ? qsTr(" (Android)") : "";
        const archiveInfo = findArchivalVersion(code)
        const ver = versionManager.versions.get(code)
        if (archiveInfo !== null && (ver === null || ver.archs.length === 1 && ver.archs[0] === archiveInfo.abi)) {
            return archiveInfo.versionName + " (" + archiveInfo.abi + ((archiveInfo.isBeta ? ", beta" : "") + ")") + suffix
        }
        if (code === page.playVerChannel.latestVersionCode)
            return page.playVerChannel.latestVersion + (playVerChannel.latestVersionIsBeta ? " (beta)" : "") + suffix
        if (ver !== null) {
            const profile = profileManager.activeProfile
            return qsTr("%1  (%2, %3)").arg(ver.versionName).arg(code).arg(profile.arch.length ? profile.arch : ver.archs.join(", ")) + suffix
        }
    }

    function getDisplayedVersionName() {
        const profile = profileManager.activeProfile
        if (profile.versionType === ProfileInfo.LATEST_GOOGLE_PLAY)
            return getDisplayedNameForCode(launcherLatestVersionscode()) || ("Unknown (" + launcherLatestVersionscode() + ")")
        if (profile.versionType === ProfileInfo.LOCKED_CODE)
            return getDisplayedNameForCode(profile.versionCode) || ((profile.versionDirName ? profile.versionDirName : "Unknown") + " (" + profile.versionCode + ")")
        if (profile.versionType === ProfileInfo.LOCKED_NAME)
            return profile.versionDirName || "Unknown Version"
        return "Unknown"
    }

    function launcherLatestVersion() {
        const showBeta = playVerChannel.latestVersionIsBeta && launcherSettings.showBetaVersions
        const versions = showBeta ? versionManager.availableArchivalVersions : versionManager.availableArchivalVersions.filter(ver => !ver.isBeta)

        const abis = googleLoginHelper.getAbis(launcherSettings.showUnsupported)
        console.log("launcherAbis: " + JSON.stringify(abis))

        const latestVersion = adjustForChromeOSMode(versions.find(ver => abis.includes(ver.abi)))
        if (latestVersion) {
            console.log("launcherLatestVersion: " + JSON.stringify(latestVersion))
            return latestVersion
        }

        console.log(abis.length === 0 ? "Unsupported Device" : "Bug: No version")

        return null
    }

    function launcherLatestVersionscode() {
        console.log("Query version")
        if (!isVersionsInitialized) {
            return 0
        }
        if (checkGooglePlayLatestSupport()) {
            console.log("Use play version")
            return page.playVerChannel.latestVersionCode
        } else {
            console.log("Use compat version")
            const ver = launcherLatestVersion()
            return ver ? ver.versionCode : 0
        }
    }
}
