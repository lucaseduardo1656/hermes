#pragma once
#include <QObject>
#include <QString>

class NavigationController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool    active      READ active      NOTIFY activeChanged)
    Q_PROPERTY(QString instruction READ instruction NOTIFY navChanged)
    Q_PROPERTY(QString distance    READ distance    NOTIFY navChanged)
    Q_PROPERTY(QString direction   READ direction   NOTIFY navChanged)
    Q_PROPERTY(double  bearing     READ bearing     NOTIFY navChanged)

public:
    explicit NavigationController(QObject *parent = nullptr);

    bool    active()      const { return m_active; }
    QString instruction() const { return m_instruction; }
    QString distance()    const { return m_distance; }
    QString direction()   const { return m_direction; }
    double  bearing()     const { return m_bearing; }

public slots:
    void startDemo();
    void stop();

signals:
    void activeChanged();
    void navChanged();

private:
    bool    m_active      = false;
    QString m_instruction;
    QString m_distance;
    QString m_direction   = "straight";
    double  m_bearing     = 0.0;
};
