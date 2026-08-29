#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
PROBE_SRC="$GITHUB_WORKSPACE/kio-probe-src"
PROBE_BUILD="$GITHUB_WORKSPACE/kio-probe-build"
rm -rf "$PROBE_SRC" "$PROBE_BUILD"
mkdir -p "$PROBE_SRC"

cat > "$PROBE_SRC/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.24)
project(syncut_kio_probe LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(KF6KIO CONFIG REQUIRED)
add_executable(syncut-kio-probe main.cpp)
target_link_libraries(syncut-kio-probe PRIVATE Qt6::Core KF6::KIOCore)
CMAKE

cat > "$PROBE_SRC/main.cpp" <<'CPP'
#include <QCoreApplication>
#include <QFile>
#include <QDebug>
#include <QLibraryInfo>
#include <QTemporaryDir>
#include <QUrl>
#include <KIO/StatJob>
#include <KIO/UDSEntry>
#include <KJob>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("syncut-kio-probe"));

    qInfo().noquote() << "PrefixPath=" << QLibraryInfo::path(QLibraryInfo::PrefixPath);
    qInfo().noquote() << "PluginsPath=" << QLibraryInfo::path(QLibraryInfo::PluginsPath);
    qInfo().noquote() << "LibraryExecutablesPath=" << QLibraryInfo::path(QLibraryInfo::LibraryExecutablesPath);
    qInfo().noquote() << "DataPath=" << QLibraryInfo::path(QLibraryInfo::DataPath);

    QTemporaryDir temp;
    if (!temp.isValid()) {
        qCritical() << "Unable to create temporary directory";
        return 10;
    }
    const QString filePath = temp.filePath(QStringLiteral("syncut-kio-file-probe.txt"));
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCritical().noquote() << "Unable to create probe file:" << file.errorString();
        return 11;
    }
    file.write("Syncut KIO local-file protocol probe\n");
    file.close();

    KIO::StatJob *job = KIO::stat(QUrl::fromLocalFile(filePath), KIO::HideProgressInfo);
    job->setAutoDelete(false);
    const bool ok = job->exec();
    if (!ok || job->error()) {
        qCritical().noquote() << "KIO_STAT_FAILED code=" << job->error() << "message=" << job->errorString();
        delete job;
        return 20;
    }
    const KIO::UDSEntry result = job->statResult();
    const QString name = result.stringValue(KIO::UDSEntry::UDS_NAME);
    delete job;
    if (name.isEmpty()) {
        qCritical() << "KIO stat returned no file name";
        return 21;
    }
    qInfo().noquote() << "KIO_FILE_PROTOCOL_OK name=" << name;
    return 0;
}
CPP

KIO_CONFIG="/ucrt64/lib/cmake/KF6KIO/KF6KIOConfig.cmake"
[ -f "$KIO_CONFIG" ] || { echo "ERROR: KF6KIO CMake package is missing: $KIO_CONFIG"; exit 30; }
cmake -S "$PROBE_SRC" -B "$PROBE_BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH=/ucrt64 \
  -DKF6KIO_DIR=/ucrt64/lib/cmake/KF6KIO \
  -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
cmake --build "$PROBE_BUILD" -j2
test -f "$PROBE_BUILD/syncut-kio-probe.exe"
