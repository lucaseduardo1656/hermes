#pragma once
#include <QObject>
#include <QString>
#include <QSettings>
#include <QVariantList>
#include <QTimer>

// Controls system-wide audio: ALSA master volume, EQ preset,
// resume-on-start flag, and spatial audio toggle.
//
// Volume is applied to the ALSA Master control via amixer so it
// affects all audio outputs, not just mpv. EQ preset is persisted
// to QSettings; PlayerController reads "eqFilter" on mpv init and
// AudioController::eqPresetChanged is connected in main.cpp to apply
// the filter live to a running mpv instance.
class AudioController : public QObject {
    Q_OBJECT
    Q_PROPERTY(int          volume        READ volume        WRITE setVolume        NOTIFY volumeChanged)
    Q_PROPERTY(bool         muted         READ muted         WRITE setMuted         NOTIFY mutedChanged)
    Q_PROPERTY(QString      eqPreset      READ eqPreset      WRITE setEqPreset      NOTIFY eqPresetChanged)
    Q_PROPERTY(bool         resumeOnStart READ resumeOnStart WRITE setResumeOnStart NOTIFY resumeOnStartChanged)
    Q_PROPERTY(bool         spatialAudio  READ spatialAudio  WRITE setSpatialAudio  NOTIFY spatialAudioChanged)
    Q_PROPERTY(QVariantList eqOptions     READ eqOptions     CONSTANT)

public:
    explicit AudioController(QObject *parent = nullptr);

    int          volume()        const { return m_volume; }
    bool         muted()         const { return m_muted; }
    QString      eqPreset()      const { return m_eqPreset; }
    bool         resumeOnStart() const { return m_resumeOnStart; }
    bool         spatialAudio()  const { return m_spatialAudio; }
    QVariantList eqOptions()     const;

    // mpv `af` filter string for the current preset. Empty = passthrough.
    Q_INVOKABLE QString eqFilterString() const;

public slots:
    void setVolume(int v);
    void setMuted(bool on);
    void setEqPreset(const QString &key);
    void setResumeOnStart(bool on);
    void setSpatialAudio(bool on);

signals:
    void volumeChanged();
    void mutedChanged();
    void eqPresetChanged();
    void resumeOnStartChanged();
    void spatialAudioChanged();

private:
    void applyAlsaVolume(int v);
    void applyMute(bool on);

    QSettings m_settings;
    int     m_volume        = 70;
    bool    m_muted         = false;
    QString m_eqPreset;
    bool    m_resumeOnStart = true;
    bool    m_spatialAudio  = false;

    // Slider drags fire setVolume() per pixel. Spawning wpctl and sync()'ing
    // QSettings (an SD-card flush) on every step locks the UI. Both are
    // coalesced: m_volumeApply throttles the wpctl call to the latest value,
    // m_persist debounces the disk write until the user stops moving.
    QTimer  m_volumeApply;
    QTimer  m_persist;
};
