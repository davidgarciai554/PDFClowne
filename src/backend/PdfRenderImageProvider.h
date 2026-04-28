#pragma once

#include <QHash>
#include <QImage>
#include <QMutex>
#include <QQuickImageProvider>
#include <QString>

class PdfRenderImageProvider : public QQuickImageProvider
{
public:
    PdfRenderImageProvider();

    QString storeImage(const QString &cacheKey, const QImage &image);
    void removeImageForKey(const QString &cacheKey);
    void removeImagesForPrefix(const QString &cacheKeyPrefix);
    void clear();

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    static QString idForKey(const QString &cacheKey);

    QMutex m_mutex;
    QHash<QString, QString> m_keyToId;
    QHash<QString, QImage> m_images;
};
