#include "PlayerController.h"

#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QUrlQuery>

PlayerController::PlayerController(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    connect(&m_pollTimer, &QTimer::timeout, this, &PlayerController::pollStatus);
    m_pollTimer.start(8000);
    pollStatus();
}

PlayerController::~PlayerController() = default;

// ── Lazy player init ──────────────────────────────────────────────────────────

bool PlayerController::ensurePlayer()
{
    if (m_player) return true;
    m_player = new QMediaPlayer(this);
    m_audio  = new QAudioOutput(this);
    m_player->setAudioOutput(m_audio);
    connect(m_player, &QMediaPlayer::playbackStateChanged,
            this, &PlayerController::onPlayerStateChanged);
    connect(m_player, &QMediaPlayer::mediaStatusChanged,
            this, &PlayerController::onMediaStatusChanged);
    connect(m_player, &QMediaPlayer::errorOccurred,
            this, &PlayerController::onPlayerError);
    connect(m_player, &QMediaPlayer::positionChanged,
            this, &PlayerController::progressChanged);
    connect(m_player, &QMediaPlayer::durationChanged,
            this, &PlayerController::durationChanged);
    return true;
}

// ── Properties ────────────────────────────────────────────────────────────────

qreal PlayerController::progress() const
{
    if (!m_player || m_player->duration() <= 0) return 0.0;
    return qreal(m_player->position()) / qreal(m_player->duration());
}

// ── Playback controls ─────────────────────────────────────────────────────────

void PlayerController::togglePlay()
{
    if (!m_player) return;
    if (m_player->playbackState() == QMediaPlayer::PlayingState)
        m_player->pause();
    else
        m_player->play();
}

void PlayerController::previous()
{
    if (m_player && m_player->position() > 3000) {
        m_player->setPosition(0);
        return;
    }
    advanceQueue(-1);
}

void PlayerController::next()
{
    advanceQueue(1);
}

void PlayerController::seekTo(qreal fraction)
{
    if (!m_player || m_player->duration() <= 0) return;
    m_player->setPosition(qint64(fraction * m_player->duration()));
}

void PlayerController::advanceQueue(int delta)
{
    if (m_queue.isEmpty()) return;
    int next = m_queueIndex + delta;
    if (next < 0 || next >= m_queue.size()) return;
    m_queueIndex = next;
    emit queueChanged();
    playTrack(m_queue.at(m_queueIndex));
}

// ── Track playback ────────────────────────────────────────────────────────────

void PlayerController::playTrack(const QVariant &track)
{
    setLoading(true);
    resolveAndPlay(track);
}

void PlayerController::playQueue(const QList<QVariant> &tracks, int index)
{
    m_queue      = tracks;
    m_queueIndex = qBound(0, index, tracks.size() - 1);
    emit queueChanged();
    if (!tracks.isEmpty())
        playTrack(tracks.at(m_queueIndex));
}

void PlayerController::resolveAndPlay(const QVariant &track)
{
    QVariantMap t = track.toMap();
    setTrack(track);

    QJsonObject body = QJsonObject::fromVariantMap(t);
    QByteArray  json = QJsonDocument(body).toJson(QJsonDocument::Compact);

    post("/resolve", json, [this, track](const QJsonObject &resp) {
        setLoading(false);
        QString url = resp.value("url").toString();
        if (url.isEmpty()) {
            qWarning() << "[PlayerController] resolve returned empty url";
            return;
        }
        if (!ensurePlayer()) return;
        m_player->setSource(QUrl(url));
        m_player->play();

        // Notify daemon
        QVariantMap t = track.toMap();
        QJsonObject body = QJsonObject::fromVariantMap(t);
        post("/played", QJsonDocument(body).toJson(QJsonDocument::Compact));
    });
}

void PlayerController::setTrack(const QVariant &t)
{
    QVariantMap m  = t.toMap();
    m_trackTitle   = m.value("title").toString();
    m_trackArtist  = m.value("artist").toString();
    m_trackAlbum   = m.value("album").toString();
    m_trackArtwork = m.value("artwork").toString();
    m_trackId      = m.value("id").toString();
    m_currentTrack = t;
    emit trackChanged();
}

void PlayerController::setLoading(bool v)
{
    if (m_loading == v) return;
    m_loading = v;
    emit loadingChanged();
}

// ── Content loading ───────────────────────────────────────────────────────────

void PlayerController::loadHome()
{
    setLoading(true);
    get("/home", [this](const QJsonObject &resp) {
        setLoading(false);
        QList<QVariant> sections;
        for (const QJsonValue &s : resp.value("sections").toArray())
            sections.append(s.toVariant());
        emit homeLoaded(sections);
    });
}

void PlayerController::loadLiked(const QString &source)
{
    setLoading(true);
    get(QString("/library/liked?source=%1").arg(source), [this](const QJsonObject &resp) {
        setLoading(false);
        QList<QVariant> tracks;
        for (const QJsonValue &v : resp.value("tracks").toArray())
            tracks.append(v.toVariant());
        emit tracksLoaded(tracks, "liked");
    });
}

void PlayerController::loadPlaylistTracks(const QString &playlistId)
{
    setLoading(true);
    get(QString("/playlists/%1/tracks").arg(playlistId), [this, playlistId](const QJsonObject &resp) {
        setLoading(false);
        QList<QVariant> tracks;
        for (const QJsonValue &v : resp.value("tracks").toArray())
            tracks.append(v.toVariant());
        emit tracksLoaded(tracks, playlistId);
    });
}

void PlayerController::search(const QString &query, const QString &source)
{
    setLoading(true);
    QUrl url = daemonUrl("/search");
    QUrlQuery q;
    q.addQueryItem("q", query);
    q.addQueryItem("source", source);
    url.setQuery(q);

    QNetworkRequest req(url);
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        setLoading(false);
        if (reply->error() != QNetworkReply::NoError) return;
        QJsonObject resp = QJsonDocument::fromJson(reply->readAll()).object();
        QList<QVariant> tracks;
        for (const QJsonValue &v : resp.value("tracks").toArray())
            tracks.append(v.toVariant());
        emit tracksLoaded(tracks, "search");
    });
}

// ── Status polling ────────────────────────────────────────────────────────────

void PlayerController::pollStatus()
{
    get("/status", [this](const QJsonObject &resp) {
        bool ok = resp.value("ok").toBool();
        if (ok != m_daemonReady) {
            m_daemonReady = ok;
            emit daemonReadyChanged();
        }
        QVariantMap srcs = resp.value("sources").toObject().toVariantMap();
        if (srcs != m_sources) {
            m_sources = srcs;
            emit sourcesChanged();
        }
    });
}

// ── Player event handlers ─────────────────────────────────────────────────────

void PlayerController::onPlayerStateChanged(QMediaPlayer::PlaybackState state)
{
    bool playing = (state == QMediaPlayer::PlayingState);
    if (m_playing != playing) {
        m_playing = playing;
        emit playingChanged();
    }
}

void PlayerController::onMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    if (status == QMediaPlayer::EndOfMedia)
        next();
}

void PlayerController::onPlayerError(QMediaPlayer::Error, const QString &msg)
{
    qWarning() << "[PlayerController] media error:" << msg;
    setLoading(false);
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────

QUrl PlayerController::daemonUrl(const QString &path) const
{
    return QUrl(m_daemonHost + path);
}

void PlayerController::get(const QString &path,
                            std::function<void(const QJsonObject &)> cb)
{
    QNetworkRequest req(daemonUrl(path));
    QNetworkReply  *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [reply, cb]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        cb(QJsonDocument::fromJson(reply->readAll()).object());
    });
}

void PlayerController::post(const QString &path, const QByteArray &body,
                             std::function<void(const QJsonObject &)> cb)
{
    QNetworkRequest req(daemonUrl(path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    QNetworkReply *reply = m_nam->post(req, body);
    connect(reply, &QNetworkReply::finished, this, [reply, cb]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        if (cb) cb(QJsonDocument::fromJson(reply->readAll()).object());
    });
}
