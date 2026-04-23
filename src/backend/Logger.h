#pragma once

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QDateTime>
#include <QTextStream>
#include <QtGlobal>

class Logger {
public:
    static void install() {
        qInstallMessageHandler(Logger::handler);
    }

private:
    static void handler(QtMsgType type, const QMessageLogContext &, const QString &msg) {
        const QString logDir = QStandardPaths::writableLocation(
                                   QStandardPaths::AppLocalDataLocation) + "/logs";
        QDir().mkpath(logDir);
        const QString logPath = logDir + "/pdfclowne.log";

        QFileInfo fi(logPath);
        if (fi.exists() && fi.size() > 5LL * 1024 * 1024) {
            const QString oldPath = logPath + ".old";
            QFile::remove(oldPath);
            QFile::rename(logPath, oldPath);
        }

        QFile file(logPath);
        if (!file.open(QIODevice::Append | QIODevice::Text))
            return;

        const char *level = "DEBUG";
        switch (type) {
        case QtInfoMsg:     level = "INFO";     break;
        case QtWarningMsg:  level = "WARNING";  break;
        case QtCriticalMsg: level = "CRITICAL"; break;
        case QtFatalMsg:    level = "FATAL";    break;
        default: break;
        }

        QTextStream out(&file);
        out << '[' << QDateTime::currentDateTime().toString(Qt::ISODate) << "] "
            << '[' << level << "] " << msg << '\n';

        if (type == QtFatalMsg)
            abort();
    }
};
