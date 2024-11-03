#include "kraidmonitor.h"
#include <QDir>
#include <QFile>
#include <QQmlExtensionPlugin>
#include <QTimer>
#include <QQmlEngine>


KRaidMonitor::KRaidMonitor(QObject *parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
    , m_icon(QStringLiteral("drive-harddisk"))
    , m_status(QStringLiteral("Unknown"))
    , m_updateInterval(3) // Set in seconds if multiplied in setUpdateInterval
{
    connect(m_timer, &QTimer::timeout, this, &KRaidMonitor::updateArrayStatus);
    m_timer->start(m_updateInterval * 1000); // Convert to ms for the timer
    updateAvailableArrays();
}

KRaidMonitor::~KRaidMonitor() = default;

void KRaidMonitor::setSelectedArray(const QString &array)
{
    if (m_selectedArray != array) {
        m_selectedArray = array;
        Q_EMIT selectedArrayChanged();
        updateArrayStatus();
    }
}

void KRaidMonitor::setUpdateInterval(int interval)
{
    if (m_updateInterval != interval) {
        m_updateInterval = interval;
        m_timer->setInterval(interval * 1000); // Set interval in ms
        Q_EMIT updateIntervalChanged();
    }
}

void KRaidMonitor::updateArrayStatus()
{
    if (m_selectedArray.isEmpty()) {
        m_status = QStringLiteral("No array selected");
        m_icon = QStringLiteral("drive-harddisk");
        Q_EMIT statusChanged();
        Q_EMIT iconChanged();
        return;
    }

    QString statePath = QStringLiteral("/sys/block/%1/md/array_state").arg(m_selectedArray);
    QString syncActionPath = QStringLiteral("/sys/block/%1/md/sync_action").arg(m_selectedArray);

    QFile stateFile(statePath);
    QFile syncActionFile(syncActionPath);

    if (stateFile.open(QIODevice::ReadOnly) && syncActionFile.open(QIODevice::ReadOnly)) {
        QString state = QString::fromUtf8(stateFile.readAll()).trimmed();
        QString syncAction = QString::fromUtf8(syncActionFile.readAll()).trimmed();

        if (syncAction == QLatin1String("check") || syncAction == QLatin1String("repair") || syncAction == QLatin1String("resync")) {
            m_status = QStringLiteral("Syncing");
            m_icon = QStringLiteral("drive-harddisk-updating");
        } else if (state == QLatin1String("clean") || state == QLatin1String("active")) {
            m_status = QStringLiteral("OK");
            m_icon = QStringLiteral("drive-harddisk");
        } else if (state == QLatin1String("degraded")) {
            m_status = QStringLiteral("Degraded");
            m_icon = QStringLiteral("drive-harddisk-warning");
        } else {
            m_status = QStringLiteral("Error: ") + state;
            m_icon = QStringLiteral("drive-harddisk-error");
        }
    } else {
        m_status = QStringLiteral("Error: Cannot read array state");
        m_icon = QStringLiteral("drive-harddisk-error");
    }

    Q_EMIT statusChanged();
    Q_EMIT iconChanged();
}

void KRaidMonitor::updateAvailableArrays()
{
    QDir mdDir(QStringLiteral("/sys/block/"));
    QStringList mdDevices = mdDir.entryList(QStringList() << QStringLiteral("md*"), QDir::Dirs);

    m_availableArrays.clear();
    for (const QString &mdDevice : mdDevices) {
        m_availableArrays.append(QVariantMap{{QStringLiteral("text"), mdDevice}, {QStringLiteral("value"), mdDevice}});
    }

    Q_EMIT availableArraysChanged();

    if (m_availableArrays.isEmpty()) {
        m_selectedArray.clear();
        Q_EMIT selectedArrayChanged();
    } else if (m_selectedArray.isEmpty()) {
        m_selectedArray = m_availableArrays.first().toMap()[QStringLiteral("value")].toString();
        Q_EMIT selectedArrayChanged();
    }
    updateArrayStatus();
}

class KRaidMonitorPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QLatin1String(uri) == QLatin1String("org.kde.plasma.private.kraidmonitor"));
        qmlRegisterType<KRaidMonitor>(uri, 1, 0, "KRaidMonitor");
    }
};

#include "kraidmonitor.moc"
