#pragma once
#include <QObject>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QList>
#include <QVariant>
#include <QString>
#include <QUrl>
#include <functional>

struct mpv_handle;

// Music playback driven by libmpv (industry-standard, used by mpv, Jellyfin,
// Plasma Bigscreen, etc.). libmpv handles progressive HTTP cache, seek, and
// pause natively — Qt's QMediaPlayer + GStreamer souphttpsrc tore down the
// pipeline on seek/pause, which broke UX with streamed YouTube URLs.
class PlayerController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool    playing     READ playing     NOTIFY playingChanged)
    Q_PROPERTY(qreal   progress    READ progress    NOTIFY progressChanged)
    Q_PROPERTY(qint64  positionMs  READ positionMs  NOTIFY progressChanged)
    Q_PROPERTY(qint64  durationMs  READ durationMs  NOTIFY durationChanged)
    Q_PROPERTY(QString trackTitle  READ trackTitle  NOTIFY trackChanged)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY trackChanged)
    Q_PROPERTY(QString trackAlbum  READ trackAlbum  NOTIFY trackChanged)
    Q_PROPERTY(QString trackArtwork READ trackArtwork NOTIFY trackChanged)
    Q_PROPERTY(QList<QVariant> queue     READ queue      NOTIFY queueChanged)
    Q_PROPERTY(int             queueIndex READ queueIndex NOTIFY queueChanged)
    Q_PROPERTY(bool  daemonReady READ daemonReady NOTIFY daemonReadyChanged)
    Q_PROPERTY(bool  loading     READ loading     NOTIFY loadingChanged)
    Q_PROPERTY(QVariantMap sources READ sources   NOTIFY sourcesChanged)
    Q_PROPERTY(bool  liked       READ liked       NOTIFY likedChanged)
    Q_PROPERTY(QString trackId   READ trackId     NOTIFY trackChanged)

public:
    explicit PlayerController(QObject *parent = nullptr);
    ~PlayerController() override;

    bool    playing()     const { return m_playing; }
    qreal   progress()    const;
    qint64  positionMs()  const { return m_positionMs; }
    qint64  durationMs()  const { return m_durationMs; }
    QString trackTitle()  const { return m_trackTitle; }
    QString trackArtist() const { return m_trackArtist; }
    QString trackAlbum()  const { return m_trackAlbum; }
    QString trackArtwork()const { return m_trackArtwork; }
    QList<QVariant> queue()     const { return m_queue; }
    int    queueIndex()   const { return m_queueIndex; }
    bool   daemonReady()  const { return m_daemonReady; }
    bool   loading()      const { return m_loading; }
    QVariantMap sources() const { return m_sources; }
    bool   liked()        const { return m_liked; }
    QString trackId()     const { return m_trackId; }

public slots:
    void togglePlay();
    void previous();
    void next();
    void seekTo(qreal fraction);

    void playTrack(const QVariant &track);
    void playQueue(const QList<QVariant> &tracks, int index = 0);
    void toggleFavorite();
    // Apply an mpv `af` filter string live. Empty string clears all filters.
    // Called from main.cpp when AudioController::eqPresetChanged fires.
    void setAudioFilter(const QString &afString);
    // Stop mpv, drop the queue, blank the now-playing track. Used by
    // the player card's close button — the auto-hide rule in Main.qml
    // keys off trackTitle being empty.
    void clear();

    void loadHome();          // reset feed + fetch first page
    void loadMoreHome();       // append next page; no-op once exhausted
    void loadLiked(const QString &source = "all");
    void loadPlaylistTracks(const QString &playlistId);
    void search(const QString &query, const QString &source = "all");

signals:
    void playingChanged();
    void progressChanged();
    void durationChanged();
    void trackChanged();
    void queueChanged();
    void daemonReadyChanged();
    void loadingChanged();
    void sourcesChanged();
    void likedChanged();

    void tracksLoaded(QList<QVariant> tracks, QString context);
    // Emitted on every successful /home response. `replace=true` means the
    // feed was reset (initial load); `replace=false` means the new
    // sections should be appended to the existing list (infinite scroll).
    void homeLoaded(QList<QVariant> sections, bool replace);

private:
    bool ensurePlayer();
    void pollStatus();
    void resolveAndPlay(const QVariant &track);
    void advanceQueue(int delta);
    void setTrack(const QVariant &t);
    void setLoading(bool v);
    void checkLiked();

    // Drain queued mpv events on the Qt thread. Called from a queued slot
    // dispatched by the libmpv wakeup callback (which runs on mpv's thread).
    void drainMpvEvents();

    void get(const QString &path,
             std::function<void(const QJsonObject &)> cb);
    void post(const QString &path, const QByteArray &body,
              std::function<void(const QJsonObject &)> cb = {});
    QUrl daemonUrl(const QString &path) const;

    static constexpr const char *kDaemonHost            = "http://127.0.0.1:8765";
    static constexpr int          kPollIntervalMs        = 8000;
    static constexpr int          kHomePageSize          = 4;
    static constexpr qint64       kPreviousSeekThresholdMs = 3000;
    static constexpr qreal        kSeekFractionCap       = 0.999;

    QNetworkAccessManager *m_nam  = nullptr;
    mpv_handle            *m_mpv  = nullptr;
    QTimer                 m_pollTimer;

    bool    m_playing     = false;
    qint64  m_positionMs  = 0;
    qint64  m_durationMs  = 0;
    QString m_trackTitle;
    QString m_trackArtist;
    QString m_trackAlbum;
    QString m_trackArtwork;

    QList<QVariant> m_queue;
    int  m_queueIndex   = 0;
    int  m_homeOffset   = 0;     // next offset to request for /home
    bool m_homeHasMore  = true;
    bool m_homeLoading  = false; // in-flight /home request guard
    bool m_daemonReady = false;
    bool m_loading     = false;
    bool m_liked       = false;
    QString m_trackId;
    QVariantMap m_sources;

    Q_INVOKABLE void _mpvWakeupQueued();   // entry point for queued wakeups
};
