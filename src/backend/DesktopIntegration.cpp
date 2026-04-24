#include "DesktopIntegration.h"

#include <QDesktopServices>
#include <QUrl>

DesktopIntegration::DesktopIntegration(QObject *parent)
    : QObject(parent)
{
}

bool DesktopIntegration::openDefaultAppsSettings() const
{
#ifdef Q_OS_WIN
    return QDesktopServices::openUrl(QUrl(QStringLiteral("ms-settings:defaultapps")));
#else
    return false;
#endif
}
