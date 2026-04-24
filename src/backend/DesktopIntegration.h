#pragma once

#include <QObject>

class DesktopIntegration : public QObject
{
    Q_OBJECT

public:
    explicit DesktopIntegration(QObject *parent = nullptr);

    Q_INVOKABLE bool openDefaultAppsSettings() const;
};
