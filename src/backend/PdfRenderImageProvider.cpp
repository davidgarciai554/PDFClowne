#include "PdfRenderImageProvider.h"

#include <QCryptographicHash>
#include <QMutexLocker>
#include <QSize>

PdfRenderImageProvider::PdfRenderImageProvider()
    : QQuickImageProvider(QQmlImageProviderBase::Image,
                          QQmlImageProviderBase::ForceAsynchronousImageLoading)
{
}

QString PdfRenderImageProvider::storeImage(const QString &cacheKey, const QImage &image)
{
    if (cacheKey.isEmpty() || image.isNull())
        return {};

    const QString id = idForKey(cacheKey);
    {
        QMutexLocker locker(&m_mutex);
        m_keyToId.insert(cacheKey, id);
        m_images.insert(id, image);
    }

    return QStringLiteral("image://pdf-render/%1").arg(id);
}

void PdfRenderImageProvider::removeImageForKey(const QString &cacheKey)
{
    QMutexLocker locker(&m_mutex);
    const QString id = m_keyToId.take(cacheKey);
    if (!id.isEmpty())
        m_images.remove(id);
}

void PdfRenderImageProvider::removeImagesForPrefix(const QString &cacheKeyPrefix)
{
    QMutexLocker locker(&m_mutex);
    for (auto it = m_keyToId.begin(); it != m_keyToId.end();) {
        if (!it.key().startsWith(cacheKeyPrefix)) {
            ++it;
            continue;
        }

        m_images.remove(it.value());
        it = m_keyToId.erase(it);
    }
}

void PdfRenderImageProvider::clear()
{
    QMutexLocker locker(&m_mutex);
    m_keyToId.clear();
    m_images.clear();
}

QImage PdfRenderImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QImage image;
    {
        QMutexLocker locker(&m_mutex);
        image = m_images.value(id);
    }

    if (size)
        *size = image.size();

    if (image.isNull() || requestedSize.isEmpty() || image.size() == requestedSize)
        return image;

    return image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
}

QString PdfRenderImageProvider::idForKey(const QString &cacheKey)
{
    const QByteArray digest = QCryptographicHash::hash(cacheKey.toUtf8(), QCryptographicHash::Sha256);
    return QString::fromLatin1(digest.toHex());
}
