// part of domlogo - visualize DOMJudge judgedaemon output
// Copyright (C) 2018  Tobias Polzer, Google LLC (tobiasp@google.com)
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#include <iostream>

#include <QGuiApplication>
#include <QQuickWindow>
#include <QtQml/QQmlApplicationEngine>

#include "logthread.h"

int main(int argc, char** argv) {
	QGuiApplication app(argc, argv);
	QQmlApplicationEngine engine;
	engine.load(QUrl(QStringLiteral("qrc:/domlogo.qml")));

	QQuickWindow *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());

	LogThread log_thread;
	log_thread.start();
	QObject::connect(&log_thread, SIGNAL(correct()), window, SLOT(correct()));
	QObject::connect(&log_thread, SIGNAL(wrong()), window, SLOT(wrong()));
	QObject::connect(&log_thread, SIGNAL(team(QVariant)), window, SLOT(team(QVariant)));
	window->setVisible(true);

	return app.exec();
}
