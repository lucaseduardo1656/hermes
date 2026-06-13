#include "PlayerController.h"

#include <QNetworkRequest>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

#include <mpv/client.h>

namespace {
// Property reply IDs used with mpv_observe_property; values are arbitrary,
// just need to be distinct so we can route MPV_EVENT_PROPERTY_CHANGE.
constexpr uint64_t kPropTimePos     = 1;
constexpr uint64_t kPropDuration    = 2;
constexpr uint64_t kPropPause       = 3;
constexpr uint64_t kPropEofReached  = 4;

// mpv_set_wakeup_callback fires on the mpv worker thread. Re-enter the Qt
// thread via a queued invocation, then drain events there.
void mpvWakeupTrampoline(void *ctx)
{
    auto *self = static_cast<PlayerController *>(ctx);
    QMetaObject::invokeMethod(self, "_mpvWakeupQueued", Qt::QueuedConnection);
}
} // namespace

PlayerController::PlayerController(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    connect(&m_pollTimer, &QTimer::timeout, this, &PlayerController::pollStatus);
    m_pollTimer.start(kPollIntervalMs);
    pollStatus();
}

PlayerController::~PlayerController()
{
    if (m_mpv) {
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
    }
}

// ── Lazy player init ──────────────────────────────────────────────────────────

bool PlayerController::ensurePlayer()
{
    if (m_mpv) return true;

    m_mpv = mpv_create();
    if (!m_mpv) {
        qWarning() << "[PlayerController] mpv_create failed";
        return false;
    }

    // Audio-only, no terminal UI, no built-in yt-dlp (we resolve via daemon).
    mpv_set_option_string(m_mpv, "vid",                   "no");
    mpv_set_option_string(m_mpv, "audio-display",         "no");
    mpv_set_option_string(m_mpv, "ytdl",                  "no");
    mpv_set_option_string(m_mpv, "terminal",              "no");
    mpv_set_option_string(m_mpv, "input-default-bindings","no");
    mpv_set_option_string(m_mpv, "input-vo-keyboard",     "no");
    mpv_set_option_string(m_mpv, "idle",                  "yes");

    // Progressive download cache — this is the whole reason we picked libmpv.
    // Streams to disk while playing so pause/seek are local, instant.
    mpv_set_option_string(m_mpv, "cache",              "yes");
    mpv_set_option_string(m_mpv, "cache-secs",         "300");
    mpv_set_option_string(m_mpv, "demuxer-max-bytes",  "150MiB");
    mpv_set_option_string(m_mpv, "demuxer-readahead-secs", "60");

    // Apply persisted EQ filter. Written by AudioController when the user
    // picks a preset. Must be set before mpv_initialize so the filter is
    // active from the first frame of audio.
    {
        QSettings s(QStringLiteral("hermes"), QStringLiteral("elise"));
        const QByteArray af = s.value(QStringLiteral("eqFilter")).toString().toUtf8();
        if (!af.isEmpty())
            mpv_set_option_string(m_mpv, "af", af.constData());
    }

    if (mpv_initialize(m_mpv) < 0) {
        qWarning() << "[PlayerController] mpv_initialize failed";
        mpv_destroy(m_mpv);
        m_mpv = nullptr;
        return false;
    }

    mpv_observe_property(m_mpv, kPropTimePos,    "time-pos",    MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, kPropDuration,   "duration",    MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, kPropPause,      "pause",       MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, kPropEofReached, "eof-reached", MPV_FORMAT_FLAG);

    // Surface mpv errors/warnings to stderr (journalctl picks them up via
    // the elise unit). Temporary while we debug seek/pause behaviour.
    mpv_request_log_messages(m_mpv, "info");

    mpv_set_wakeup_callback(m_mpv, &mpvWakeupTrampoline, this);
    return true;
}

// ── Properties ────────────────────────────────────────────────────────────────

qreal PlayerController::progress() const
{
    if (m_durationMs <= 0) return 0.0;
    return qreal(m_positionMs) / qreal(m_durationMs);
}

// ── Playback controls ─────────────────────────────────────────────────────────

void PlayerController::setAudioFilter(const QString &afString) {
    if (!m_mpv) return;
    mpv_set_property_string(m_mpv, "af",
                            afString.isEmpty() ? "" : afString.toUtf8().constData());
}

void PlayerController::togglePlay()
{
    if (!m_mpv) return;
    int paused = 0;
    mpv_get_property(m_mpv, "pause", MPV_FORMAT_FLAG, &paused);
    int target = paused ? 0 : 1;
    mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &target);
}

void PlayerController::previous()
{
    if (m_mpv && m_positionMs > kPreviousSeekThresholdMs) {
        double zero = 0.0;
        mpv_set_property(m_mpv, "time-pos", MPV_FORMAT_DOUBLE, &zero);
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
    if (!m_mpv || m_durationMs <= 0) return;
    // Cap below 1.0 — seeking exactly to duration triggers immediate EOF
    // and auto-advances the queue, which the user reads as "skipped".
    fraction = qBound<qreal>(0.0, fraction, kSeekFractionCap);
    double target = (fraction * m_durationMs) / 1000.0;   // seconds
    mpv_set_property(m_mpv, "time-pos", MPV_FORMAT_DOUBLE, &target);
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

void PlayerController::clear()
{
    if (m_mpv) {
        const char *cmd[] = { "stop", nullptr };
        mpv_command(m_mpv, cmd);
    }
    m_queue.clear();
    m_queueIndex   = 0;
    m_trackTitle.clear();
    m_trackArtist.clear();
    m_trackAlbum.clear();
    m_trackArtwork.clear();
    m_positionMs   = 0;
    m_durationMs   = 0;
    m_playing      = false;
    emit trackChanged();
    emit queueChanged();
    emit progressChanged();
    emit durationChanged();
    emit playingChanged();
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

        const QByteArray urlUtf8 = url.toUtf8();
        const char *cmd[] = { "loadfile", urlUtf8.constData(), nullptr };
        int rc = mpv_command(m_mpv, cmd);
        if (rc < 0) {
            qWarning() << "[PlayerController] mpv loadfile failed:" << mpv_error_string(rc);
            return;
        }

        // mpv defaults to playing on load; ensure pause=no.
        int unpause = 0;
        mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &unpause);

        // Notify daemon (for /played history).
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
    m_liked        = false;   // reset until checkLiked responds
    emit trackChanged();
    emit likedChanged();
    checkLiked();
}

void PlayerController::checkLiked()
{
    if (m_trackId.isEmpty()) return;
    const QString id = m_trackId;   // capture for lambda
    get(QStringLiteral("/library/liked/check?id=") + QUrl::toPercentEncoding(id),
        [this, id](const QJsonObject &resp) {
            if (id != m_trackId) return;   // track changed while request was in flight
            const bool liked = resp.value(QStringLiteral("liked")).toBool();
            if (liked != m_liked) { m_liked = liked; emit likedChanged(); }
        });
}

void PlayerController::toggleFavorite()
{
    if (m_trackId.isEmpty()) return;
    // Optimistic: flip immediately so the UI responds without a round-trip.
    m_liked = !m_liked;
    emit likedChanged();
    QJsonObject body;
    body[QStringLiteral("id")] = m_trackId;
    const QByteArray json = QJsonDocument(body).toJson(QJsonDocument::Compact);
    post(m_liked ? QStringLiteral("/library/like") : QStringLiteral("/library/unlike"), json);
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
    // Reset pagination state then fetch the first page.
    m_homeOffset  = 0;
    m_homeHasMore = true;
    m_homeLoading = false;
    loadMoreHome();
}

void PlayerController::loadMoreHome()
{
    if (m_homeLoading || !m_homeHasMore) return;
    m_homeLoading = true;
    if (m_homeOffset == 0) setLoading(true);

    const QString path = QString("/home?offset=%1&limit=%2")
                             .arg(m_homeOffset).arg(kHomePageSize);
    const int requestedOffset = m_homeOffset;

    get(path, [this, requestedOffset](const QJsonObject &resp) {
        m_homeLoading = false;
        if (requestedOffset == 0) setLoading(false);

        QList<QVariant> sections;
        for (const QJsonValue &s : resp.value("sections").toArray())
            sections.append(s.toVariant());

        m_homeOffset  = requestedOffset + sections.size();
        m_homeHasMore = resp.value("has_more").toBool();

        emit homeLoaded(sections, /*replace=*/ requestedOffset == 0);
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
        bool wasReady = m_daemonReady;
        if (ok != m_daemonReady) {
            m_daemonReady = ok;
            emit daemonReadyChanged();
        }
        QVariantMap srcs = resp.value("sources").toObject().toVariantMap();
        if (srcs != m_sources) {
            m_sources = srcs;
            emit sourcesChanged();
        }
        // Daemon just came back online — reset the feed so we re-fetch
        // a fresh /home. Covers "device was on a captive portal /
        // tunnel went down" recovery without forcing the user to tap
        // Recarregar manually.
        if (ok && !wasReady) {
            loadHome();
            return;
        }
        // Boot flow: daemon was already reachable but we never landed
        // a populated feed (first request hit before clock sync / DNS
        // came up). Quietly retry the first page.
        if (ok && m_homeOffset == 0 && !m_homeLoading) {
            loadMoreHome();
        }
    });
}

// ── mpv event pump ────────────────────────────────────────────────────────────

void PlayerController::_mpvWakeupQueued()
{
    drainMpvEvents();
}

void PlayerController::drainMpvEvents()
{
    if (!m_mpv) return;
    while (true) {
        mpv_event *ev = mpv_wait_event(m_mpv, 0);
        if (!ev || ev->event_id == MPV_EVENT_NONE) break;

        switch (ev->event_id) {
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto *p = static_cast<mpv_event_property *>(ev->data);
            switch (ev->reply_userdata) {
            case kPropTimePos: {
                if (p->format == MPV_FORMAT_DOUBLE) {
                    double s = *static_cast<double *>(p->data);
                    qint64 ms = qint64(s * 1000.0);
                    if (ms != m_positionMs) {
                        m_positionMs = ms;
                        emit progressChanged();
                    }
                }
                break;
            }
            case kPropDuration: {
                if (p->format == MPV_FORMAT_DOUBLE) {
                    double s = *static_cast<double *>(p->data);
                    qint64 ms = qint64(s * 1000.0);
                    if (ms != m_durationMs) {
                        m_durationMs = ms;
                        emit durationChanged();
                    }
                }
                break;
            }
            case kPropPause: {
                if (p->format == MPV_FORMAT_FLAG) {
                    int paused = *static_cast<int *>(p->data);
                    bool playing = !paused;
                    if (playing != m_playing) {
                        m_playing = playing;
                        emit playingChanged();
                    }
                }
                break;
            }
            case kPropEofReached: {
                if (p->format == MPV_FORMAT_FLAG) {
                    int eof = *static_cast<int *>(p->data);
                    if (eof) next();
                }
                break;
            }
            default: break;
            }
            break;
        }
        case MPV_EVENT_END_FILE: {
            auto *ef = static_cast<mpv_event_end_file *>(ev->data);
            // Only auto-advance on natural end; ignore user-initiated stops.
            if (ef && ef->reason == MPV_END_FILE_REASON_EOF)
                next();
            break;
        }
        case MPV_EVENT_LOG_MESSAGE: {
            auto *m = static_cast<mpv_event_log_message *>(ev->data);
            qWarning() << "[mpv]" << m->prefix << m->text;
            break;
        }
        case MPV_EVENT_SHUTDOWN:
            return;
        default:
            break;
        }
    }
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────

QUrl PlayerController::daemonUrl(const QString &path) const
{
    return QUrl(QString(kDaemonHost) + path);
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
