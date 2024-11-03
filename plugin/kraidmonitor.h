#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

class KRaidMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString icon READ icon NOTIFY iconChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QVariantList availableArrays READ availableArrays NOTIFY availableArraysChanged)
    Q_PROPERTY(QString selectedArray READ selectedArray WRITE setSelectedArray NOTIFY selectedArrayChanged)
    Q_PROPERTY(int updateInterval READ updateInterval WRITE setUpdateInterval NOTIFY updateIntervalChanged)

public:
    explicit KRaidMonitor(QObject *parent = nullptr);
    ~KRaidMonitor();

    QString icon() const { return m_icon; }
    QString status() const { return m_status; }
    QVariantList availableArrays() const { return m_availableArrays; }
    QString selectedArray() const { return m_selectedArray; }
    void setSelectedArray(const QString &array);
    int updateInterval() const { return m_updateInterval; }
    void setUpdateInterval(int interval);

    Q_INVOKABLE void updateAvailableArrays();

public Q_SLOTS:
    void updateArrayStatus();

Q_SIGNALS:
    void iconChanged();
    void statusChanged();
    void availableArraysChanged();
    void selectedArrayChanged();
    void updateIntervalChanged();

private:
    QTimer *m_timer;
    QString m_icon;
    QString m_status;
    QVariantList m_availableArrays;
    QString m_selectedArray;
    int m_updateInterval;
};
