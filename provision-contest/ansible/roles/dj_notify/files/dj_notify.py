from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import subprocess
import gi
import os
import webbrowser
import subprocess
import traceback
gi.require_version('Notify', '0.7')
from gi.repository import Notify

HOSTNAME = "0.0.0.0"
PORT = 9999
ALSA_DEVICE = os.environ['ALSA_DEVICE']
NOTIFICATION_SOUND = os.environ['NOTIFICATION_SOUND']
NOTIFICATION_SOUND_VOLUME = int(os.environ['NOTIFICATION_SOUND_VOLUME'])


def on_notification_closed(notification):
    print(f"Notification {notification.id} closed.")


def on_link_click(notification, action, link):
    webbrowser.open(link)


def filter_notification(title, body, link):
    return not title.startswith("Symfony\\Component\\HttpKernel\\Exception\\NotFoundHttpException")


class NotifyServer(BaseHTTPRequestHandler):
    def create_notification(self, title, body, link):
        notification = Notify.Notification.new(title, body)
        notification.connect("closed", on_notification_closed)
        notification.add_action(
            "action_click",
            "View in browser",
            on_link_click,
            link
        )
        notification.show()


    def notification_sound(self, sound):
        # Use Popen to launch a non-blocking background process
        subprocess.Popen(["paplay", "--volume", str(NOTIFICATION_SOUND_VOLUME), "--device", ALSA_DEVICE, sound])


    def do_POST(self):
        length = int(self.headers.get('Content-Length'))
        body = self.rfile.read(length)
        content = json.loads(body)
        print(json.dumps(content, indent=2))

        att = content['attachments'][0]
        title = att['title']
        link = att['title_link']
        body = att['text']

        if filter_notification(title, body, link):
            try:
                self.create_notification(title, body, link)
            except Exception:
                print(traceback.format_exc())
            try:
                self.notification_sound(NOTIFICATION_SOUND)
            except Exception:
                print(traceback.format_exc())

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()

        self.wfile.write(bytes("ok", "utf-8"))


Notify.init("DOMjudge notifications")
server = HTTPServer((HOSTNAME, PORT), NotifyServer)

try:
    server.serve_forever()
except KeyboardInterrupt:
    pass

# Clean up
server.server_close()
Notify.uninit()
