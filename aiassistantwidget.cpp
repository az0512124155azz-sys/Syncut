#include "aiassistantwidget.h"

#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QHBoxLayout>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPushButton>
#include <QTextBrowser>
#include <QTextEdit>
#include <QUrl>
#include <QVBoxLayout>

SyncutAiAssistantWidget::SyncutAiAssistantWidget(QWidget *parent)
    : QWidget(parent)
    , m_network(new QNetworkAccessManager(this))
{
    setLayoutDirection(Qt::RightToLeft);
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(10, 10, 10, 10);
    layout->setSpacing(8);

    auto *title = new QLabel(tr("עוזר Syncut AI"), this);
    QFont titleFont = title->font();
    titleFont.setBold(true);
    titleFont.setPointSize(titleFont.pointSize() + 2);
    title->setFont(titleFont);
    layout->addWidget(title);

    m_status = new QLabel(tr("בודק AI מקומי..."), this);
    m_status->setObjectName(QStringLiteral("syncutAiStatus"));
    layout->addWidget(m_status);

    m_history = new QTextBrowser(this);
    m_history->setOpenExternalLinks(false);
    m_history->setPlaceholderText(tr("כאן תופיע השיחה. Syncut לא מוריד מודל AI בעצמו."));
    layout->addWidget(m_history, 1);

    m_input = new QTextEdit(this);
    m_input->setPlaceholderText(tr("כתוב מה אתה רוצה לעשות בפרויקט..."));
    m_input->setMaximumHeight(110);
    layout->addWidget(m_input);

    auto *buttons = new QHBoxLayout();
    m_attach = new QPushButton(tr("צרף קבצים"), this);
    m_send = new QPushButton(tr("שלח"), this);
    m_send->setEnabled(false);
    buttons->addWidget(m_attach);
    buttons->addStretch(1);
    buttons->addWidget(m_send);
    layout->addLayout(buttons);

    connect(m_attach, &QPushButton::clicked, this, &SyncutAiAssistantWidget::attachFiles);
    connect(m_send, &QPushButton::clicked, this, &SyncutAiAssistantWidget::sendMessage);
    probeRuntime();
}

bool SyncutAiAssistantWidget::runtimeAvailable() const
{
    return !m_model.isEmpty();
}

void SyncutAiAssistantWidget::probeRuntime()
{
    QNetworkRequest req(QUrl(QStringLiteral("http://127.0.0.1:11434/api/tags")));
    auto *reply = m_network->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray bytes = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            m_model.clear();
            m_send->setEnabled(false);
            m_status->setText(tr("לא נמצא AI מקומי פעיל. אפשר להשתמש ב-Syncut בלי AI."));
            reply->deleteLater();
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(bytes);
        const QJsonArray models = doc.object().value(QStringLiteral("models")).toArray();
        if (models.isEmpty()) {
            m_model.clear();
            m_send->setEnabled(false);
            m_status->setText(tr("נמצא מנוע AI, אבל אין בו מודל מותקן."));
        } else {
            m_model = models.first().toObject().value(QStringLiteral("name")).toString();
            m_send->setEnabled(!m_model.isEmpty());
            m_status->setText(tr("מחובר ל-AI מקומי: %1").arg(m_model));
        }
        reply->deleteLater();
    });
}

void SyncutAiAssistantWidget::attachFiles()
{
    const QStringList files = QFileDialog::getOpenFileNames(this, tr("צרף קבצים לעוזר AI"), QString(),
                                                            tr("קבצים נתמכים (*.txt *.md *.srt *.vtt *.json *.csv *.png *.jpg *.jpeg *.webp);;כל הקבצים (*)"));
    for (const QString &path : files) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            continue;
        }
        QByteArray bytes = file.read(10 * 1024 * 1024);
        const QString ext = QFileInfo(path).suffix().toLower();
        if (ext == QStringLiteral("png") || ext == QStringLiteral("jpg") || ext == QStringLiteral("jpeg") || ext == QStringLiteral("webp")) {
            m_imageAttachments.push_back(bytes.toBase64());
        } else {
            if (bytes.size() > 100 * 1024) {
                bytes.truncate(100 * 1024);
            }
            m_textAttachments.push_back(qMakePair(QFileInfo(path).fileName(), bytes));
        }
        appendLine(tr("מערכת"), tr("צורף: %1").arg(QFileInfo(path).fileName()));
    }
}

QString SyncutAiAssistantWidget::promptWithAttachments(const QString &text) const
{
    QString prompt = text;
    for (const auto &item : m_textAttachments) {
        prompt += QStringLiteral("\n\n--- Attachment: %1 ---\n%2").arg(item.first, QString::fromUtf8(item.second));
    }
    return prompt;
}

void SyncutAiAssistantWidget::sendMessage()
{
    const QString userText = m_input->toPlainText().trimmed();
    if (userText.isEmpty() || m_model.isEmpty()) {
        return;
    }
    appendLine(tr("אתה"), userText);
    m_input->clear();
    m_send->setEnabled(false);

    QJsonObject systemMessage;
    systemMessage.insert(QStringLiteral("role"), QStringLiteral("system"));
    systemMessage.insert(QStringLiteral("content"),
                         QStringLiteral("You are Syncut AI, an assistant for a professional video editor. The user may write Hebrew or English. "
                                        "Understand Hebrew by internally translating it to English when useful, reason precisely, and always answer the user in natural Hebrew. "
                                        "Do not claim an edit was performed unless the host application explicitly confirms it. Give concrete editing instructions and project plans."));

    QJsonObject userMessage;
    userMessage.insert(QStringLiteral("role"), QStringLiteral("user"));
    userMessage.insert(QStringLiteral("content"), promptWithAttachments(userText));
    if (!m_imageAttachments.isEmpty()) {
        QJsonArray images;
        for (const QByteArray &img : m_imageAttachments) {
            images.push_back(QString::fromLatin1(img));
        }
        userMessage.insert(QStringLiteral("images"), images);
    }

    QJsonArray messages;
    messages.push_back(systemMessage);
    messages.push_back(userMessage);

    QJsonObject body;
    body.insert(QStringLiteral("model"), m_model);
    body.insert(QStringLiteral("stream"), false);
    body.insert(QStringLiteral("messages"), messages);

    QNetworkRequest req(QUrl(QStringLiteral("http://127.0.0.1:11434/api/chat")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    auto *reply = m_network->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_send->setEnabled(!m_model.isEmpty());
        if (reply->error() != QNetworkReply::NoError) {
            appendLine(tr("Syncut AI"), tr("שגיאת חיבור ל-AI המקומי: %1").arg(reply->errorString()));
            reply->deleteLater();
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QString answer = doc.object().value(QStringLiteral("message")).toObject().value(QStringLiteral("content")).toString();
        appendLine(tr("Syncut AI"), answer.isEmpty() ? tr("התקבלה תשובה ריקה מהמודל.") : answer);
        m_textAttachments.clear();
        m_imageAttachments.clear();
        reply->deleteLater();
    });
}

void SyncutAiAssistantWidget::appendLine(const QString &speaker, const QString &text)
{
    m_history->append(QStringLiteral("<p dir=\"rtl\"><b>%1:</b> %2</p>").arg(speaker.toHtmlEscaped(), text.toHtmlEscaped().replace('\n', QStringLiteral("<br>"))));
}
