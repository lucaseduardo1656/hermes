#include "MusicBackend.h"

#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDesktopServices>
#include <QUrl>

MusicBackend::MusicBackend(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_player(new QMediaPlayer(this))
    , m_audio(new QAudioOutput(this))
{
    m_player->setAudioOutput(m_audio);

    connect(m_player, &QMediaPlayer::playbackStateChanged,
            this, &MusicBackend::onPlayerStateChanged);
    connect(m_player, &QMediaPlayer::mediaStatusChanged,
            this, &MusicBackend::onMediaStatusChanged);
    connect(m_player, &QMediaPlayer::errorOccurred,
            this, &MusicBackend::onPlayerError);
    connect(m_player, &QMediaPlayer::positionChanged,
            this, &MusicBackend::progressChanged);
    connect(m_player, &QMediaPlayer::durationChanged,
            this, &MusicBackend::durationChanged);

    // Poll daemon status every 10s; first check immediately
    connect(&m_pollTimer, &QTimer::timeout, this, &MusicBackend::pollDaemon);
    m_pollTimer.start(10000);
    pollDaemon();
}

MusicBackend::~MusicBackend() = default;

// ── Properties ────────────────────────────────────────────────────────────────

qreal MusicBackend::progress() const
{
    const qint64 dur = m_player->duration();
    if (dur <= 0) return 0.0;
    return static_cast<qreal>(m_player->position()) / dur;
}

qint64 MusicBackend::positionMs() const { return m_player->position(); }
qint64 MusicBackend::durationMs() const { return m_player->duration(); }

// ── Networking helpers ────────────────────────────────────────────────────────

QUrl MusicBackend::daemonUrl(const QString &path) const
{
    return QUrl(m_daemonHost + path);
}

void MusicBackend::get(const QString &path, std::function<void(const QByteArray &)> cb)
{
    QNetworkRequest req(daemonUrl(path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    auto *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit error(reply->errorString());
            return;
        }
        cb(reply->readAll());
    });
}

void MusicBackend::post(const QString &path, const QByteArray &body,
                        std::function<void(const QByteArray &)> cb)
{
    QNetworkRequest req(daemonUrl(path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    auto *reply = m_nam->post(req, body);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit error(reply->errorString());
            return;
        }
        cb(reply->readAll());
    });
}

void MusicBackend::del(const QString &path, std::function<void()> cb)
{
    QNetworkRequest req(daemonUrl(path));
    auto *reply = m_nam->deleteResource(req);
    connect(reply, &QNetworkReply::finished, this, [reply, cb]() {
        reply->deleteLater();
        cb();
    });
}

// ── Daemon polling ────────────────────────────────────────────────────────────

void MusicBackend::pollDaemon()
{
    get(QStringLiteral("/status"), [this](const QByteArray &data) {
        updateSourceStatus(data);
    });
}

void MusicBackend::updateSourceStatus(const QByteArray &data)
{
    const QJsonObject root = QJsonDocument::fromJson(data).object();
    const bool ready = root.value(QStringLiteral("ok")).toBool();

    if (m_daemonReady != ready) {
        m_daemonReady = ready;
        emit daemonReadyChanged();
    }

    const QJsonObject sources = root.value(QStringLiteral("sources")).toObject();
    bool changed = false;

    auto update = [&](bool &field, const QString &key) {
        const bool val = sources.value(key).toBool();
        if (field != val) { field = val; changed = true; }
    };

    update(m_spotifyConnected,    QStringLiteral("spotify"));
    update(m_ytmusicConnected,    QStringLiteral("ytmusic"));
    update(m_soundcloudConnected, QStringLiteral("soundcloud"));

    if (changed) emit sourcesChanged();
}

// ── Auth ──────────────────────────────────────────────────────────────────────

void MusicBackend::connectSpotify()
{
    get(QStringLiteral("/auth/spotify/start"), [this](const QByteArray &data) {
        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        const QString url = obj.value(QStringLiteral("url")).toString();
        if (!url.isEmpty()) {
            emit spotifyAuthUrlReady(url);
            QDesktopServices::openUrl(QUrl(url));
        }
    });
}

void MusicBackend::disconnectSpotify()
{
    del(QStringLiteral("/auth/spotify"), [this]() {
        m_spotifyConnected = false;
        emit sourcesChanged();
    });
}

void MusicBackend::connectYtMusic()
{
    get(QStringLiteral("/auth/ytmusic/instructions"), [this](const QByteArray &data) {
        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        emit ytmusicInstructionsReady(obj.value(QStringLiteral("instructions")).toString());
    });
}

void MusicBackend::uploadYtMusicOAuth(const QString &jsonContent)
{
    post(QStringLiteral("/auth/ytmusic/upload"),
         jsonContent.toUtf8(),
         [this](const QByteArray &data) {
             const QJsonObject obj = QJsonDocument::fromJson(data).object();
             if (obj.value(QStringLiteral("ok")).toBool()) {
                 m_ytmusicConnected = true;
                 emit sourcesChanged();
             }
         });
}

// ── Browse ────────────────────────────────────────────────────────────────────

void MusicBackend::loadPlaylists(const QString &source)
{
    get(QStringLiteral("/playlists?source=") + source, [this](const QByteArray &data) {
        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        m_playlists.clear();
        for (const QJsonValue &v : obj.value(QStringLiteral("playlists")).toArray())
            m_playlists.append(v.toVariant());
        emit playlistsChanged();
    });
}

void MusicBackend::loadPlaylistTracks(const QString &playlistId)
{
    const QString encoded = QString::fromUtf8(QUrl::toPercentEncoding(playlistId));
    get(QStringLiteral("/playlists/") + encoded + QStringLiteral("/tracks"),
        [this, playlistId](const QByteArray &data) {
            const QJsonObject obj = QJsonDocument::fromJson(data).object();
            QVariantList tracks;
            for (const QJsonValue &v : obj.value(QStringLiteral("tracks")).toArray())
                tracks.append(v.toVariant());
            emit tracksLoaded(tracks, playlistId);
        });
}

void MusicBackend::loadRecommendations()
{
    get(QStringLiteral("/recommendations"), [this](const QByteArray &data) {
        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        QVariantList tracks;
        for (const QJsonValue &v : obj.value(QStringLiteral("tracks")).toArray())
            tracks.append(v.toVariant());
        emit tracksLoaded(tracks, QStringLiteral("recommendations"));
    });
}

void MusicBackend::loadLiked(const QString &source)
{
    get(QStringLiteral("/library/liked?source=") + source, [this](const QByteArray &data) {
        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        QVariantList tracks;
        for (const QJsonValue &v : obj.value(QStringLiteral("tracks")).toArray())
            tracks.append(v.toVariant());
        emit tracksLoaded(tracks, QStringLiteral("liked"));
    });
}

void MusicBackend::search(const QString &query, const QString &source)
{
    const QString encoded = QString::fromUtf8(QUrl::toPercentEncoding(query));
    get(QStringLiteral("/search?q=") + encoded + QStringLiteral("&source=") + source,
        [this](const QByteArray &data) {
            const QJsonObject obj = QJsonDocument::fromJson(data).object();
            QVariantList tracks;
            for (const QJsonValue &v : obj.value(QStringLiteral("tracks")).toArray())
                tracks.append(v.toVariant());
            emit tracksLoaded(tracks, QStringLiteral("search"));
        });
}

// ── Playback ──────────────────────────────────────────────────────────────────

void MusicBackend::playTrack(const QVariantMap &track)
{
    m_queue.clear();
    m_queue.append(track);
    m_queueIndex = 0;
    emit queueChanged();
    resolveAndPlay(track);
}

void MusicBackend::playPlaylist(const QVariantList &tracks, int startIndex)
{
    if (tracks.isEmpty()) return;
    m_queue      = tracks;
    m_queueIndex = qBound(0, startIndex, tracks.size() - 1);
    emit queueChanged();
    resolveAndPlay(m_queue.at(m_queueIndex).toMap());
}

void MusicBackend::appendToQueue(const QVariantMap &track)
{
    m_queue.append(track);
    emit queueChanged();
}

void MusicBackend::clearQueue()
{
    m_queue.clear();
    m_queueIndex = -1;
    m_player->stop();
    emit queueChanged();
}

void MusicBackend::resolveAndPlay(const QVariantMap &track)
{
    m_loading = true;
    emit loadingChanged();

    const QByteArray body = QJsonDocument(QJsonObject::fromVariantMap(track)).toJson();
    post(QStringLiteral("/resolve"), body, [this, track](const QByteArray &data) {
        m_loading = false;
        emit loadingChanged();

        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        const QString url = obj.value(QStringLiteral("url")).toString();
        if (url.isEmpty()) {
            emit error(QStringLiteral("Failed to resolve stream URL"));
            return;
        }
        playResolved(track, url);
    });
}

void MusicBackend::playResolved(const QVariantMap &track, const QString &streamUrl)
{
    m_trackTitle   = track.value(QStringLiteral("title")).toString();
    m_trackArtist  = track.value(QStringLiteral("artist")).toString();
    m_trackAlbum   = track.value(QStringLiteral("album")).toString();
    m_trackArtwork = track.value(QStringLiteral("artwork")).toString();
    m_trackSource  = track.value(QStringLiteral("source")).toString();
    emit trackChanged();

    m_player->setSource(QUrl(streamUrl));
    m_player->play();
}

void MusicBackend::play()    { m_player->play(); }
void MusicBackend::pause()   { m_player->pause(); }

void MusicBackend::togglePlay()
{
    if (m_player->playbackState() == QMediaPlayer::PlayingState)
        m_player->pause();
    else
        m_player->play();
}

void MusicBackend::seekTo(qreal fraction)
{
    const qint64 dur = m_player->duration();
    if (dur > 0)
        m_player->setPosition(static_cast<qint64>(fraction * dur));
}

void MusicBackend::next()
{
    if (m_queue.isEmpty() || m_queueIndex < 0) return;
    const int next = m_queueIndex + 1;
    if (next >= m_queue.size()) return;
    m_queueIndex = next;
    emit queueChanged();
    resolveAndPlay(m_queue.at(m_queueIndex).toMap());
}

void MusicBackend::previous()
{
    // If >3s into track, restart; otherwise go to previous
    if (m_player->position() > 3000) {
        m_player->setPosition(0);
        return;
    }
    if (m_queue.isEmpty() || m_queueIndex <= 0) return;
    m_queueIndex--;
    emit queueChanged();
    resolveAndPlay(m_queue.at(m_queueIndex).toMap());
}

// ── Player event handlers ─────────────────────────────────────────────────────

void MusicBackend::onPlayerStateChanged(QMediaPlayer::PlaybackState state)
{
    const bool playing = (state == QMediaPlayer::PlayingState);
    if (m_playing != playing) {
        m_playing = playing;
        emit playingChanged();
    }
}

void MusicBackend::onMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    if (status == QMediaPlayer::EndOfMedia) {
        next(); // auto-advance queue
    }
}

void MusicBackend::onPlayerError(QMediaPlayer::Error /*error*/, const QString &errorString)
{
    emit error(QStringLiteral("Playback error: ") + errorString);
}
