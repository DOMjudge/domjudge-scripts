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
import QtQuick 2.0
import QtQuick.Window 2.2

Window {
	flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
	color: "black"
	x: 1000
	y: 60
	id: "window"
	minimumHeight: domjudge.height + uni.height
	height: domjudge.height + uni.height
	width: height / (dummy.paintedHeight+dummy.paintedWidth) * dummy.paintedWidth;
	Image {
		id: "dummy"
		source: "DOMjudgelogo_sticker.svg"
		fillMode: Image.PreserveAspectFit
		width: 100
		height: 100
		visible: false
	}
	function correct() {
		green.opacity = 1
		red.opacity = 0
		timer.restart()
	}
	function wrong() {
		red.opacity = 1
		green.opacity = 0
		timer.restart()
	}
	Timer {
		interval: 1000
		repeat: true
		running: true
		onTriggered: {
			window.x = 1000
			window.y = 50
		}
	}
	Timer {
		id: "timer"
		interval: 1000
		onTriggered: {
			red.opacity = 0
			green.opacity = 0
		}
	}
	Rectangle {
		id: "domjudge"
		color: "transparent"
		anchors.left: parent.left
		anchors.right: parent.right
		height: 480
		Image {
			id: "image"
			anchors.fill: parent
			source: "DOMjudgelogo_sticker.svg"
			fillMode: Image.PreserveAspectFit
			sourceSize.width: width
			sourceSize.height: height
		}
		Image {
			id: "red"
			anchors.fill: parent
			source: "DOMjudgelogo_sticker_red.svg"
			fillMode: Image.PreserveAspectFit
			sourceSize.width: width
			sourceSize.height: height
			opacity: 0
			Behavior on opacity {
				NumberAnimation {}
			}
		}
		Image {
			id: "green"
			anchors.fill: parent
			source: "DOMjudgelogo_sticker_green.svg"
			fillMode: Image.PreserveAspectFit
			sourceSize.width: width
			sourceSize.height: height
			opacity: 0
			Behavior on opacity {
				NumberAnimation {}
			}
		}
	}
	function team(tid) {
		if (tid == "") {
			team.opacity = 0
		} else {
			team.source = tid + ".png"
			team.opacity = 1
		}
	}
	Rectangle {
		id: "uni"
		color: "transparent"
		height: {
			width
		}
		width: image.paintedWidth
		anchors.horizontalCenter: domjudge.horizontalCenter
		anchors.top: domjudge.bottom
		Image {
			id: "team"
			anchors.fill: parent
			source: ""
			sourceSize.width: width
			sourceSize.height: height
			opacity: 0
			Behavior on opacity {
				NumberAnimation {}
			}
		}
	}
}
