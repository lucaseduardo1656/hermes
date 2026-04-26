#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QNetworkAccessManager>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QTimer>
#include <QUrl>

class MusicBackend : public QObject {
    Q_OBJECT

    // ── Playback state ────────────────────────────────────────────────────────
    Q_PROPERTY(bool    playing      READ playing      NOTIFY playingChanged)
    Q_PROPERTY(bool    loading      READ loading      NOTIFY loadingChanged)
    Q_PROPERTY(qreal   progress     READ progress     NOTIFY progressChanged)
    Q_PROPERTY(qint64  positionMs   READ positionMs   NOTIFY progressChanged)
    Q_PROPERTY(qint64  durationMs   READ durationMs   NOTIFY durationChanged)
    Q_PROPERTY(QString trackTitle   READ trackTitle   NOTIFY trackChanged)
    Q_PROPERTY(QString trackArtist  READ trackArtist  NOTIFY trackChanged)
    Q_PROPERTY(QString trackAlbum   READ trackAlbum   NOTIFY trackChanged)
    Q_PROPERTY(QString trackArtwork READ trackArtwork NOTIFY trackChanged)
    Q_PROPERTY(QString trackSource  READ trackSource  NOTIFY trackChanged)

    // ── Provider connection status ────────────────────────────────────────────
    Q_PROPERTY(bool spotifyConnected    READ spotifyConnected    NOTIFY sourcesChanged)
    Q_PROPERTY(bool ytmusicConnected    READ ytmusicConnected    NOTIFY sourcesChanged)
    Q_PROPERTY(bool soundcloudConnected READ soundcloudConnected NOTIFY sourcesChanged)

    // ── Library / browse ──────────────────────────────────────────────────────
    Q_PROPERTY(QVariantList playlists    READ playlists    NOTIFY playlistsChanged)
    Q_PROPERTY(QVariantList queue        READ queue        NOTIFY queueChanged)
    Q_PROPERTY(int          queueIndex   READ queueIndex   NOTIFY queueChanged)

    // ── Daemon ────────────────────────────────────────────────────────────────
    Q_PROPERTY(bool daemonReady READ daemonReady NOTIFY daemonReadyChanged)

public:
    explicit MusicBackend(QObject *parent = nullptr);
    ~MusicBackend() override;

    bool    playing()      const { return m_playing; }
    bool    loading()      const { return m_loading; }
    qreal   progress()     const;
    qint64  positionMs()   const;
    qint64  durationMs()   const;
    QString trackTitle()   const { return m_trackTitle; }
    QString trackArtist()  const { return m_trackArtist; }
    QString trackAlbum()   const { return m_trackAlbum; }
    QString trackArtwork() const { return m_trackArtwork; }
    QString trackSource()  const { return m_trackSource; }

    bool spotifyConnected()    const { return m_spotifyConnected; }
    bool ytmusicConnected()    const { return m_ytmusicConnected; }
    bool soundcloudConnected() const { return m_soundcloudConnected; }

    QVariantList playlists()  const { return m_playlists; }
    QVariantList queue()      const { return m_queue; }
    int          queueIndex() const { return m_queueIndex; }

    bool daemonReady() const { return m_daemonReady; }

public slots:
    // Playback
    void play();
    void pause();
    void togglePlay();
    void seekTo(qreal fraction);   // 0.0 – 1.0
    void next();
    void previous();

    // Queue management
    void playTrack(const QVariantMap &track);
    void playPlaylist(const QVariantList &tracks, int startIndex = 0);
    void appendToQueue(const QVariantMap &track);
    void clearQueue();

    // Browse
    void loadPlaylists(const QString &source = QStringLiteral("all"));
    void loadPlaylistTracks(const QString &playlistId);
    void loadRecommendations();
    void loadLiked(const QString &source = QStringLiteral("all"));
    void search(const QString &query, const QString &source = QStringLiteral("all"));

    // Auth
    void connectSpotify();       // opens auth URL via QDesktopServices
    void disconnectSpotify();
    void connectYtMusic();       // shows instructions dialog (emits signal)
    void uploadYtMusicOAuth(const QString &jsonContent);

signals:
    void playingChanged();
    void loadingChanged();
    void progressChanged();
    void durationChanged();
    void trackChanged();
    void sourcesChanged();
    void playlistsChanged();
    void queueChanged();
    void daemonReadyChanged();

    // Emitted when browse results arrive (QML listens and updates model)
    void tracksLoaded(const QVariantList &tracks, const QString &context);
    void error(const QString &message);

    // Auth signals
    void spotifyAuthUrlReady(const QString &url);
    void ytmusicInstructionsReady(const QString &instructions);

private slots:
    void onPlayerStateChanged(QMediaPlayer::PlaybackState state);
    void onMediaStatusChanged(QMediaPlayer::MediaStatus status);
    void onPlayerError(QMediaPlayer::Error error, const QString &errorString);
    void pollDaemon();

private:
    QUrl    daemonUrl(const QString &path) const;
    void    get(const QString &path, std::function<void(const QByteArray &)> cb);
    void    post(const QString &path, const QByteArray &body,
                 std::function<void(const QByteArray &)> cb);
    void    del(const QString &path, std::function<void()> cb);
    void    resolveAndPlay(const QVariantMap &track);
    void    playResolved(const QVariantMap &track, const QString &streamUrl);
    void    updateSourceStatus(const QByteArray &statusJson);

    QNetworkAccessManager *m_nam  = nullptr;
    QMediaPlayer          *m_player = nullptr;
    QAudioOutput          *m_audio  = nullptr;
    QTimer                 m_pollTimer;

    // Playback state
    bool    m_playing  = false;
    bool    m_loading  = false;
    QString m_trackTitle;
    QString m_trackArtist;
    QString m_trackAlbum;
    QString m_trackArtwork;
    QString m_trackSource;

    // Source status
    bool m_spotifyConnected    = false;
    bool m_ytmusicConnected    = false;
    bool m_soundcloudConnected = false;
    bool m_daemonReady         = false;

    // Library
    QVariantList m_playlists;
    QVariantList m_queue;
    int          m_queueIndex = -1;

    const QString m_daemonHost = QStringLiteral("http://127.0.0.1:8765");
};
