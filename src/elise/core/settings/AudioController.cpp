#include "AudioController.h"

#include <QProcess>
#include <QVariantMap>

namespace {
struct EqDef { const char *key; const char *label; const char *filter; };

// lavfi equalizer chains for mpv's --af option.
// Frequencies chosen for car audio: prominent bass, moderate mids, clear highs.
static const EqDef kPresets[] = {
    { "flat",   "Plano",             "" },
    { "bass",   "Graves reforçados",
      "lavfi=[equalizer=f=60:width_type=h:width=120:g=6,"
             "equalizer=f=250:width_type=h:width=200:g=3]" },
    { "treble", "Agudos reforçados",
      "lavfi=[equalizer=f=4000:width_type=h:width=4000:g=4,"
             "equalizer=f=10000:width_type=h:width=6000:g=5]" },
    { "vocal",  "Vocal",
      "lavfi=[equalizer=f=80:width_type=h:width=200:g=-2,"
             "equalizer=f=1500:width_type=h:width=2000:g=5]" },
};
constexpr const char *kDefaultPreset = "flat";
}

AudioController::AudioController(QObject *parent)
    : QObject(parent)
    , m_settings(QStringLiteral("hermes"), QStringLiteral("elise"))
{
    m_resumeOnStart = m_settings.value(QStringLiteral("resumeOnStart"), true).toBool();
    m_spatialAudio  = m_settings.value(QStringLiteral("spatialAudio"),  false).toBool();

    m_eqPreset = m_settings.value(QStringLiteral("eqPreset"),
                                  QString::fromLatin1(kDefaultPreset)).toString();
    bool ok = false;
    for (const auto &p : kPresets)
        if (m_eqPreset == QLatin1String(p.key)) { ok = true; break; }
    if (!ok) m_eqPreset = QString::fromLatin1(kDefaultPreset);

    // Persist the resolved filter string so PlayerController can read it
    // from QSettings on mpv init without a compile-time dependency here.
    m_settings.setValue(QStringLiteral("eqFilter"), eqFilterString());

    const int persisted = m_settings.value(QStringLiteral("volume"), 70).toInt();
    m_volume = qBound(0, persisted, 100);
    m_muted  = m_settings.value(QStringLiteral("muted"), false).toBool();
    m_settings.sync();

    applyAlsaVolume(m_volume);
    applyMute(m_muted);

    // Throttle the wpctl call to ~30 Hz during a drag; only the latest value
    // matters, so coalescing is lossless for the user.
    m_volumeApply.setSingleShot(true);
    m_volumeApply.setInterval(33);
    QObject::connect(&m_volumeApply, &QTimer::timeout, this,
                     [this]{ applyAlsaVolume(m_volume); });

    // Flush to disk only once the user has settled (avoids per-step SD writes).
    m_persist.setSingleShot(true);
    m_persist.setInterval(600);
    QObject::connect(&m_persist, &QTimer::timeout, this, [this]{
        m_settings.setValue(QStringLiteral("volume"), m_volume);
        m_settings.setValue(QStringLiteral("muted"),  m_muted);
        m_settings.sync();
    });
}

QVariantList AudioController::eqOptions() const {
    QVariantList out;
    for (const auto &p : kPresets) {
        QVariantMap m;
        m.insert(QStringLiteral("key"),   QString::fromLatin1(p.key));
        m.insert(QStringLiteral("label"), QString::fromUtf8(p.label));
        out.append(m);
    }
    return out;
}

QString AudioController::eqFilterString() const {
    for (const auto &p : kPresets)
        if (m_eqPreset == QLatin1String(p.key))
            return QString::fromLatin1(p.filter);
    return {};
}

void AudioController::setVolume(int v) {
    v = qBound(0, v, 100);
    if (v == m_volume) return;
    m_volume = v;
    emit volumeChanged();          // UI updates immediately, no I/O on this path
    m_volumeApply.start();         // coalesced wpctl
    m_persist.start();             // debounced disk write
}

void AudioController::setMuted(bool on) {
    if (on == m_muted) return;
    m_muted = on;
    emit mutedChanged();
    applyMute(on);                 // single call — fine to fire now
    m_persist.start();
}

void AudioController::applyMute(bool on) {
    QProcess::startDetached(
        QStringLiteral("wpctl"),
        { QStringLiteral("set-mute"),
          QStringLiteral("@DEFAULT_AUDIO_SINK@"),
          on ? QStringLiteral("1") : QStringLiteral("0") }
    );
}

void AudioController::setEqPreset(const QString &key) {
    if (key == m_eqPreset) return;
    for (const auto &p : kPresets) {
        if (key == QLatin1String(p.key)) {
            m_eqPreset = key;
            m_settings.setValue(QStringLiteral("eqPreset"), key);
            m_settings.setValue(QStringLiteral("eqFilter"), eqFilterString());
            m_settings.sync();
            emit eqPresetChanged();
            return;
        }
    }
}

void AudioController::setResumeOnStart(bool on) {
    if (on == m_resumeOnStart) return;
    m_resumeOnStart = on;
    m_settings.setValue(QStringLiteral("resumeOnStart"), on);
    m_settings.sync();
    emit resumeOnStartChanged();
}

void AudioController::setSpatialAudio(bool on) {
    if (on == m_spatialAudio) return;
    m_spatialAudio = on;
    m_settings.setValue(QStringLiteral("spatialAudio"), on);
    m_settings.sync();
    emit spatialAudioChanged();
}

void AudioController::applyAlsaVolume(int v) {
    // Pi 5 HDMI audio has no ALSA mixer controls — use PipeWire via wpctl.
    // Fire-and-forget; if PipeWire is not yet ready the volume is persisted
    // in QSettings and reapplied on next AudioController construction.
    QProcess::startDetached(
        QStringLiteral("wpctl"),
        { QStringLiteral("set-volume"),
          QStringLiteral("@DEFAULT_AUDIO_SINK@"),
          QString::number(v) + QLatin1Char('%') }
    );
}
