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
#include "logthread.h"

#include <iostream>

namespace {
	bool goodTeam(const std::string& s) {
		try {
			int id = std::stoi(s);
			if (id <= 135) {
				return true;
			}
		} catch (const std::exception& e) {}
		return false;
	}
}

void LogThread::run() {
	std::string line;
	std::string presult = "result: ";
	std::string pjudging = ": Judging submission s";
	std::string pcorrect = "correct";
	std::string pteam = ") (t";
	std::string pnosubs = "No submissions in queue";
	while(std::getline(std::cin, line)) {
		auto it = std::search(line.begin(), line.end(), presult.begin(), presult.end());
		if (it != line.end()) {
			it += presult.size();
			if (std::equal(it, line.end(), pcorrect.begin(), pcorrect.end())) {
				emit correct();
			} else {
				emit wrong();
			}
			continue;
		}
		it = std::search(line.begin(), line.end(), pjudging.begin(), pjudging.end());
		if (it != line.end()) {
			it = std::search(it, line.end(), pteam.begin(), pteam.end());
		}
		if (it != line.end()) {
			it += pteam.size();
			auto end = std::find(it, line.end(), '/');
			std::string teamid = line.substr(it - line.begin(), end - it);
			if (goodTeam(teamid)) {
				emit team(QString::fromStdString(teamid));
			} else {
				emit team("none");
			}
			continue;
		}
		it = std::search(line.begin(), line.end(), pnosubs.begin(), pnosubs.end());
		if (it != line.end()) {
			emit team("");
			continue;
		}
	}
}

LogThread::~LogThread() {
	terminate();
}
