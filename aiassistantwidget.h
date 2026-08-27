#pragma once

#include <QWidget>
#include <QList>
#include <QByteArray>

class QNetworkAccessManager;
class QTextBrowser;
class QTextEdit;
class QPushButton;
class QLabel;

class SyncutAiAssistantWidget final : public QWidget
{
    Q_OBJECT
public:
    explicit SyncutAiAssistantWidget(QWidget *parent = nullptr);
    bool runtimeAvailable() const;

private Q_SLOTS:
    void probeRuntime();
    void attachFiles();
    void sendMessage();

private:
    void appendLine(const QString &speaker, const QString &text);
    QString promptWithAttachments(const QString &text) const;

    QNetworkAccessManager *m_network{nullptr};
    QTextBrowser *m_history{nullptr};
    QTextEdit *m_input{nullptr};
    QPushButton *m_send{nullptr};
    QPushButton *m_attach{nullptr};
    QLabel *m_status{nullptr};
    QString m_model;
    QList<QPair<QString, QByteArray>> m_textAttachments;
    QList<QByteArray> m_imageAttachments;
};
