// Offscreen renderer for the documentation screenshots.
//
// Loads package/contents/ui/main.qml with the stub modules in
// tools/shotgen/mockimports shadowing the real plugin and the Plasma applet
// API, then grabs the result to a PNG. Run through tools/shotgen/run.sh.

#include <QGuiApplication>
#include <QColor>
#include <QImage>
#include <QQmlError>
#include <QQuickItem>
#include <QQuickView>
#include <QTimer>
#include <QUrl>
#include <QtGlobal>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    // The offscreen platform reports the window as closed straight away, which
    // would end the event loop before the grab timer ever fires.
    app.setQuitOnLastWindowClosed(false);

    if (argc < 5) {
        qCritical("usage: render <main.qml> <out.png> <width> <height> [background]");
        return 2;
    }

    QQuickView view;
    // The scene is themed by the desktop's colour scheme, so the background has
    // to be passed in to match it; anti-aliased text blends against it.
    view.setColor(argc > 5 ? QColor(QString::fromLocal8Bit(argv[5])) : QColor(Qt::transparent));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.resize(QSize(QString::fromLocal8Bit(argv[3]).toInt(), QString::fromLocal8Bit(argv[4]).toInt()));
    view.setSource(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));

    if (view.status() == QQuickView::Error) {
        const auto errors = view.errors();
        for (const QQmlError &error : errors) {
            qCritical("%s", qPrintable(error.toString()));
        }
        return 1;
    }

    view.show();

    int result = 0;
    const QString outPath = QString::fromLocal8Bit(argv[2]);

    // Give the scene a moment to settle: icons resolve asynchronously, and
    // grabbing too early yields a frame with the emblems still missing.
    QTimer::singleShot(2000, &app, [&view, &app, &result, outPath]() {
        const QImage image = view.grabWindow();
        if (image.isNull()) {
            qCritical("grabWindow() returned a null image");
            result = 1;
        } else if (!image.save(outPath)) {
            qCritical("could not write %s", qPrintable(outPath));
            result = 1;
        }
        app.quit();
    });

    app.exec();
    return result;
}
