#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

class KRaidMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString rawState READ rawState NOTIFY rawStateChanged)
    Q_PROPERTY(QString level READ level NOTIFY levelChanged)
    Q_PROPERTY(int totalDisks READ totalDisks NOTIFY totalDisksChanged)
    Q_PROPERTY(int activeDisks READ activeDisks NOTIFY activeDisksChanged)
    Q_PROPERTY(qreal syncProgress READ syncProgress NOTIFY syncProgressChanged)
    Q_PROPERTY(int syncSpeed READ syncSpeed NOTIFY syncSpeedChanged)
    Q_PROPERTY(int syncEtaSeconds READ syncEtaSeconds NOTIFY syncEtaSecondsChanged)
    Q_PROPERTY(QVariantList members READ members NOTIFY membersChanged)
    Q_PROPERTY(QVariantList availableArrays READ availableArrays NOTIFY availableArraysChanged)
    Q_PROPERTY(QString selectedArray READ selectedArray WRITE setSelectedArray NOTIFY selectedArrayChanged)
    Q_PROPERTY(int updateInterval READ updateInterval WRITE setUpdateInterval NOTIFY updateIntervalChanged)

public:
    enum State {
        NoArray,
        Ok,
        Syncing,
        Degraded,
        Error,
    };
    Q_ENUM(State)

    explicit KRaidMonitor(QObject *parent = nullptr);
    ~KRaidMonitor();

    State state() const { return m_state; }
    // Raw contents of array_state, for the messages QML builds itself.
    QString rawState() const { return m_rawState; }
    QString level() const { return m_level; }
    int totalDisks() const { return m_totalDisks; }
    int activeDisks() const { return m_activeDisks; }
    // 0.0-1.0 while a sync is running, -1 when there is nothing to report.
    qreal syncProgress() const { return m_syncProgress; }
    // KB/s, or -1 when unknown.
    int syncSpeed() const { return m_syncSpeed; }
    // Seconds, or -1 when it cannot be computed.
    int syncEtaSeconds() const { return m_syncEtaSeconds; }
    // One { name, state, slot } map per member device, ordered by slot.
    QVariantList members() const { return m_members; }
    QVariantList availableArrays() const { return m_availableArrays; }
    QString selectedArray() const { return m_selectedArray; }
    void setSelectedArray(const QString &array);
    int updateInterval() const { return m_updateInterval; }
    void setUpdateInterval(int interval);

    Q_INVOKABLE void updateAvailableArrays();

public Q_SLOTS:
    void updateArrayStatus();

Q_SIGNALS:
    void stateChanged();
    void rawStateChanged();
    void levelChanged();
    void totalDisksChanged();
    void activeDisksChanged();
    void syncProgressChanged();
    void syncSpeedChanged();
    void syncEtaSecondsChanged();
    void membersChanged();
    void availableArraysChanged();
    void selectedArrayChanged();
    void updateIntervalChanged();

private:
    // Trimmed contents of /sys/block/<selectedArray>/md/<attr>, or a null
    // string when the attribute cannot be read.
    QString readAttr(const QString &attr) const;
    void clearArrayDetails();

    QTimer *m_timer;
    State m_state;
    QString m_rawState;
    QString m_level;
    int m_totalDisks;
    int m_activeDisks;
    qreal m_syncProgress;
    int m_syncSpeed;
    int m_syncEtaSeconds;
    QVariantList m_members;
    QVariantList m_availableArrays;
    QString m_selectedArray;
    int m_updateInterval;
};
