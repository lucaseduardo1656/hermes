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

public slots:
    void togglePlay();
    void previous();
    void next();
    void seekTo(qreal fraction);

    void playTrack(const QVariant &track);
    void playQueue(const QList<QVariant> &tracks, int index = 0);

    void loadHome();
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

    void tracksLoaded(QList<QVariant> tracks, QString context);
    void homeLoaded(QList<QVariant> sections);

private:
    bool ensurePlayer();
    void pollStatus();
    void resolveAndPlay(const QVariant &track);
    void advanceQueue(int delta);
    void setTrack(const QVariant &t);
    void setLoading(bool v);

    // Drain queued mpv events on the Qt thread. Called from a queued slot
    // dispatched by the libmpv wakeup callback (which runs on mpv's thread).
    void drainMpvEvents();

    void get(const QString &path,
             std::function<void(const QJsonObject &)> cb);
    void post(const QString &path, const QByteArray &body,
              std::function<void(const QJsonObject &)> cb = {});
    QUrl daemonUrl(const QString &path) const;

    QNetworkAccessManager *m_nam  = nullptr;
    mpv_handle            *m_mpv  = nullptr;
    QTimer                 m_pollTimer;

    QString m_daemonHost = "http://127.0.0.1:8765";

    bool    m_playing     = false;
    qint64  m_positionMs  = 0;
    qint64  m_durationMs  = 0;
    QString m_trackTitle;
    QString m_trackArtist;
    QString m_trackAlbum;
    QString m_trackArtwork;
    QString m_trackId;
    QVariant m_currentTrack;

    QList<QVariant> m_queue;
    int  m_queueIndex  = 0;
    bool m_daemonReady = false;
    bool m_loading     = false;
    QVariantMap m_sources;

    Q_INVOKABLE void _mpvWakeupQueued();   // entry point for queued wakeups
};
