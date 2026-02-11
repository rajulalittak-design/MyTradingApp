# PowerShell helper to run the Kivy app in a virtualenv on Windows
python -m venv .venv
if (Test-Path .venv\Scripts\Activate) {
    . .\.venv\Scripts\Activate
}
pip install --upgrade pip
pip install -r mobile_app\requirements.txt
python mobile_app\main.py
