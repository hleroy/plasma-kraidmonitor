#include "kraidmonitor.h"
#include <QDir>
#include <QFile>
#include <QQmlExtensionPlugin>
#include <QTimer>
#include <QQmlEngine>
#include <algorithm>


// "raid1" -> "RAID1", "linear" -> "Linear".
static QString formatLevel(const QString &raw)
{
    if (raw.isEmpty()) {
        return QString();
    }
    if (raw.startsWith(QLatin1String("raid"))) {
        return QLatin1String("RAID") + raw.mid(4);
    }
    QString formatted = raw;
    formatted[0] = formatted[0].toUpper();
    return formatted;
}

KRaidMonitor::KRaidMonitor(QObject *parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
    , m_state(NoArray)
    , m_rawState()
    , m_totalDisks(0)
    , m_activeDisks(0)
    , m_syncProgress(-1)
    , m_syncSpeed(-1)
    , m_syncEtaSeconds(-1)
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

QString KRaidMonitor::readAttr(const QString &attr) const
{
    if (m_selectedArray.isEmpty()) {
        return QString();
    }

    QFile file(QStringLiteral("/sys/block/%1/md/%2").arg(m_selectedArray, attr));
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromUtf8(file.readAll()).trimmed();
}

void KRaidMonitor::clearArrayDetails()
{
    if (!m_members.isEmpty()) {
        m_members.clear();
        Q_EMIT membersChanged();
    }
    if (!m_level.isEmpty()) {
        m_level.clear();
        Q_EMIT levelChanged();
    }
    if (m_totalDisks != 0) {
        m_totalDisks = 0;
        Q_EMIT totalDisksChanged();
    }
    if (m_activeDisks != 0) {
        m_activeDisks = 0;
        Q_EMIT activeDisksChanged();
    }
    if (m_syncProgress != -1) {
        m_syncProgress = -1;
        Q_EMIT syncProgressChanged();
    }
    if (m_syncSpeed != -1) {
        m_syncSpeed = -1;
        Q_EMIT syncSpeedChanged();
    }
    if (m_syncEtaSeconds != -1) {
        m_syncEtaSeconds = -1;
        Q_EMIT syncEtaSecondsChanged();
    }
}

void KRaidMonitor::updateArrayStatus()
{
    if (m_selectedArray.isEmpty()) {
        if (m_state != NoArray) {
            m_state = NoArray;
            Q_EMIT stateChanged();
        }
        if (!m_rawState.isEmpty()) {
            m_rawState.clear();
            Q_EMIT rawStateChanged();
        }
        clearArrayDetails();
        return;
    }

    const QString arrayState = readAttr(QStringLiteral("array_state"));
    const QString syncAction = readAttr(QStringLiteral("sync_action"));
    const int degraded = readAttr(QStringLiteral("degraded")).toInt();

    State state;

    if (arrayState.isEmpty()) {
        state = Error;
    } else if (syncAction == QLatin1String("check") || syncAction == QLatin1String("repair")
               || syncAction == QLatin1String("resync") || syncAction == QLatin1String("recover")
               || syncAction == QLatin1String("reshape")) {
        // Checked before the array state: a rebuilding array still reports
        // clean or active, and the sync is the more useful thing to show.
        state = Syncing;
    } else if (arrayState != QLatin1String("clean") && arrayState != QLatin1String("active")) {
        state = Error;
    } else if (degraded > 0) {
        // A failed member normally leaves array_state at clean, so the disk
        // count is what distinguishes a degraded array from a healthy one.
        state = Degraded;
    } else {
        state = Ok;
    }

    if (m_state != state) {
        m_state = state;
        Q_EMIT stateChanged();
    }
    // Display strings are built in QML so they go through i18n(); the plugin
    // only reports the state and the raw value behind it.
    if (m_rawState != arrayState) {
        m_rawState = arrayState;
        Q_EMIT rawStateChanged();
    }

    const QString level = formatLevel(readAttr(QStringLiteral("level")));
    if (m_level != level) {
        m_level = level;
        Q_EMIT levelChanged();
    }

    const int totalDisks = readAttr(QStringLiteral("raid_disks")).toInt();
    const int activeDisks = qMax(0, totalDisks - degraded);
    if (m_totalDisks != totalDisks) {
        m_totalDisks = totalDisks;
        Q_EMIT totalDisksChanged();
    }
    if (m_activeDisks != activeDisks) {
        m_activeDisks = activeDisks;
        Q_EMIT activeDisksChanged();
    }

    // sync_completed reads "<done> / <total>" in sectors while a sync runs,
    // and "none" or "delayed" otherwise.
    qreal syncProgress = -1;
    qreal remainingSectors = -1;
    const QString syncCompleted = readAttr(QStringLiteral("sync_completed"));
    const QStringList parts = syncCompleted.split(QLatin1Char('/'), Qt::SkipEmptyParts);
    if (parts.count() == 2) {
        bool doneOk = false;
        bool totalOk = false;
        const qreal done = parts.at(0).trimmed().toDouble(&doneOk);
        const qreal total = parts.at(1).trimmed().toDouble(&totalOk);
        if (doneOk && totalOk && total > 0) {
            syncProgress = qBound(qreal(0), done / total, qreal(1));
            remainingSectors = qMax(qreal(0), total - done);
        }
    }
    if (m_syncProgress != syncProgress) {
        m_syncProgress = syncProgress;
        Q_EMIT syncProgressChanged();
    }

    // sync_speed is in KB/s, or "none" when idle.
    bool speedOk = false;
    const int syncSpeed = readAttr(QStringLiteral("sync_speed")).toInt(&speedOk);
    const int speed = (speedOk && syncSpeed > 0) ? syncSpeed : -1;
    if (m_syncSpeed != speed) {
        m_syncSpeed = speed;
        Q_EMIT syncSpeedChanged();
    }

    // Sectors are 512 bytes, so two of them make up one KB of sync_speed.
    int eta = -1;
    if (speed > 0 && remainingSectors >= 0) {
        eta = static_cast<int>(remainingSectors / 2 / speed);
    }
    if (m_syncEtaSeconds != eta) {
        m_syncEtaSeconds = eta;
        Q_EMIT syncEtaSecondsChanged();
    }

    // Each member device is a dev-<name> directory holding its own state and
    // slot, which is what tells you *which* disk dropped out of the array.
    QVariantList members;
    QDir arrayDir(QStringLiteral("/sys/block/%1/md").arg(m_selectedArray));
    const QStringList memberDirs = arrayDir.entryList(QStringList() << QStringLiteral("dev-*"), QDir::Dirs);
    for (const QString &memberDir : memberDirs) {
        bool slotOk = false;
        const int slot = readAttr(memberDir + QStringLiteral("/slot")).toInt(&slotOk);
        members.append(QVariantMap{
            {QStringLiteral("name"), memberDir.mid(4)},
            {QStringLiteral("state"), readAttr(memberDir + QStringLiteral("/state"))},
            {QStringLiteral("slot"), slotOk ? slot : -1},
        });
    }
    std::sort(members.begin(), members.end(), [](const QVariant &a, const QVariant &b) {
        const QVariantMap left = a.toMap();
        const QVariantMap right = b.toMap();
        // Spares report no slot; keep them after the numbered members.
        const int leftSlot = left[QStringLiteral("slot")].toInt();
        const int rightSlot = right[QStringLiteral("slot")].toInt();
        if (leftSlot != rightSlot) {
            return (leftSlot < 0) ? false : (rightSlot < 0) ? true : leftSlot < rightSlot;
        }
        return left[QStringLiteral("name")].toString() < right[QStringLiteral("name")].toString();
    });
    if (m_members != members) {
        m_members = members;
        Q_EMIT membersChanged();
    }
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
