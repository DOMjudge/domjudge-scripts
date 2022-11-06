#!/usr/bin/python3

import PySimpleGUI as sg
import platform
import time

font = ('Andale Mono', 32)
host = platform.node()
layout = [
    [sg.Text(host, font=font)]
]
window = sg.Window('showhost', layout, location=(0,0), keep_on_top=True, no_titlebar=True)

while True:
    event, values = window.read(timeout=30)
    if event == sg.WIN_CLOSED:
        break
    # Sleep here for a second here, it doesn't really matter how fast we stop
    # the loop.
    time.sleep(1)