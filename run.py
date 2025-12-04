import sys
import os
import webbrowser
import threading
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app.app import app
def open_browser():
    threading.Timer(1.5, lambda: webbrowser.open('http://192.168.1.80:5000')).start()
if __name__ == '__main__':
    open_browser()
    app.run(debug=True, host='0.0.0.0', port=5000)
