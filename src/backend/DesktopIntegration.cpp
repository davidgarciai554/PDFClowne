#include "DesktopIntegration.h"

#include <QDesktopServices>
#include <QGuiApplication>
#include <QClipboard>
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

bool DesktopIntegration::setClipboardText(const QString &text) const
{
    if (auto *clipboard = QGuiApplication::clipboard()) {
        clipboard->setText(text);
        return true;
    }

    return false;
}
