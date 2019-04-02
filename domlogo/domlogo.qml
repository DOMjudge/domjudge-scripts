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
        color: "transparent"
	x: 500
	y: 160
	id: "window"
	minimumHeight: 580
	height: 580
	width: 1000
	Image {
		id: "dummy"
		source: "DOMjudgelogo_sticker.svg"
		fillMode: Image.PreserveAspectFit
		width: 180
		height: 180
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
			window.x = 500
			window.y = 160
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
		anchors.top: parent.top
		height: 400
		width: 180
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
		if (tid == "none") {
			team.opacity = 1
			team.source = "dummy.png"
                        photo.opacity = 1
			photo.source = "eindhoven.jpg"
		} else if (tid == "") {
			team.opacity = 0
                        photo.opacity = 0
                        uni.color = "transparent"
		} else {
			team.source = tid + ".png"
			team.opacity = 1
                        photo.opacity = 1
			photo.source = tid + ".jpg"
                        uni.color = "black"
		}
	}
	Rectangle {
		id: "uni"
		color: "black"
		height: {
			181
		}
		width: 181
		anchors.left: domjudge.left
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
	Rectangle {
		id: "photorectangle"
		color: "transparent"
		height: {
			580
		}
		width: 870
		anchors.left: uni.right;
		anchors.bottom: uni.bottom
		Image {
			id: "photo"
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
