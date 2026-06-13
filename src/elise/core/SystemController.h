#pragma once
#include <QObject>
#include <QColor>
#include <QSettings>
#include <QVariantList>

class SystemController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool darkTheme  READ isDark  WRITE setDark  NOTIFY themeChanged)
    Q_PROPERTY(QString accentKey READ accentKey WRITE setAccentKey NOTIFY themeChanged)
    Q_PROPERTY(QVariantList accentOptions READ accentOptions CONSTANT)

    Q_PROPERTY(QColor background    READ background    NOTIFY themeChanged)
    Q_PROPERTY(QColor surface       READ surface       NOTIFY themeChanged)
    Q_PROPERTY(QColor surface2      READ surface2      NOTIFY themeChanged)
    Q_PROPERTY(QColor accent        READ accent        NOTIFY themeChanged)
    Q_PROPERTY(QColor accentDim     READ accentDim     NOTIFY themeChanged)
    Q_PROPERTY(QColor textPrimary   READ textPrimary   NOTIFY themeChanged)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY themeChanged)
    Q_PROPERTY(QColor textMuted     READ textMuted     NOTIFY themeChanged)
    Q_PROPERTY(QColor textDisabled  READ textDisabled  NOTIFY themeChanged)
    Q_PROPERTY(QColor border        READ border        NOTIFY themeChanged)
    Q_PROPERTY(QColor overlay       READ overlay       NOTIFY themeChanged)
    Q_PROPERTY(QColor pressOverlay  READ pressOverlay  CONSTANT)
    Q_PROPERTY(QColor danger        READ danger        CONSTANT)
    Q_PROPERTY(QColor success       READ success       CONSTANT)
    Q_PROPERTY(QColor warning       READ warning       CONSTANT)

public:
    explicit SystemController(QObject *parent = nullptr);

    bool isDark() const { return m_dark; }
    void setDark(bool dark);
    QString accentKey()    const { return m_accentKey; }
    void setAccentKey(const QString &k);
    QVariantList accentOptions() const;

    QColor background()    const { return m_dark ? QColor("#0A0A0A") : QColor("#F5F5F5"); }
    QColor surface()       const { return m_dark ? QColor("#1C1C1C") : QColor("#FFFFFF"); }
    QColor surface2()      const { return m_dark ? QColor("#2A2A2A") : QColor("#EBEBEB"); }
    QColor accent()        const;
    QColor accentDim()     const;
    QColor textPrimary()   const { return m_dark ? QColor("#EAEAEA") : QColor("#111111"); }
    QColor textSecondary() const { return m_dark ? QColor("#909090") : QColor("#555555"); }
    QColor textMuted()     const { return m_dark ? QColor("#555555") : QColor("#999999"); }
    QColor textDisabled()  const { return m_dark ? QColor("#333333") : QColor("#BBBBBB"); }
    QColor border()        const { return m_dark ? QColor("#2E2E2E") : QColor("#DDDDDD"); }
    QColor overlay()       const { return m_dark ? QColor(0, 0, 0, 180) : QColor(0, 0, 0, 80); }
    QColor pressOverlay()  const { return QColor(255, 255, 255, 18); }
    QColor danger()        const { return QColor("#E5484D"); }
    QColor success()       const { return QColor("#3DB07F"); }
    QColor warning()       const { return QColor("#E8B339"); }

signals:
    void themeChanged();

private:
    QSettings m_settings;
    bool      m_dark      = true;
    QString   m_accentKey;
};
