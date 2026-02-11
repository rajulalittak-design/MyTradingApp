# Journal Mobile App (Kivy)

This mobile app reads and appends rows to your existing `JOURNAL.xlsm` while preserving macros (`keep_vba=True`). It is an offline Android-capable app scaffold written with Kivy.

Files added:
- `main.py` — Kivy app UI and Excel handling.
- `requirements.txt` — Python dependencies for testing and packaging.

Quick desktop test (Windows):

1. Create and activate a virtualenv in the project root (optional but recommended).

```powershell
python -m venv .venv
.\.venv\Scripts\activate
# Journal Mobile App (Kivy)

This mobile app reads and appends rows to your existing `JOURNAL.xlsm` while preserving macros (`keep_vba=True`). It is an offline Android-capable app scaffold written with Kivy.

Files added:
- `main.py` — Kivy app UI and Excel handling.
- `requirements.txt` — Python dependencies for testing and packaging.

Quick desktop test (Windows)

1. Create and activate a virtualenv in the project root (optional but recommended):

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r mobile_app\requirements.txt
python mobile_app\main.py
```

2. Place your existing `JOURNAL.xlsm` (the same workbook you're using) in the project root (`c:\Users\dell\Desktop\MyTradingApp\JOURNAL.xlsm`). The app reads headers from row 9 and will append new rows after the end of the sheet.

Building an APK (notes)

- Building an Android APK typically requires a Linux environment (or WSL with extra setup). The recommended path is to use `buildozer` (Linux) or use the included GitHub Actions workflow which runs `buildozer` inside a Docker image.
- I added `buildozer.spec` and a `.github/workflows/build_apk.yml` workflow to this repo. The workflow runs on pushes to `main` or via manual `workflow_dispatch` and will produce an APK in `bin/` which is uploaded as an artifact.
- The app bundles a copy-on-first-run logic: the APK should include `JOURNAL.xlsm` (see `buildozer.spec` `source.include_exts`). On first run the app copies that bundled workbook into the app's writable `user_data_dir` and uses that copy for subsequent reads/writes, preserving macros (`keep_vba=True`).

What I can do next for you

- Customize the UI (validation, date/time pickers, P&L auto-calculation).
- Add code to export the workbook to a user-visible download folder on Android (external storage) for easier sharing.
- Create a GitHub release PR and help you run the workflow if you want me to prepare the repo for CI.

Export behavior

An "Export to Downloads" button exists in the UI. On desktop it copies the current `JOURNAL.xlsm` to your `Downloads` folder; on Android the app attempts to write to the public Downloads folder via `pyjnius` (runtime storage permissions requested). For modern Android versions SAF (Storage Access Framework) is often preferable — I can add SAF support if you want.

How to get the APK from CI

1. Push your repository to GitHub on the `main` branch.
2. Open the Actions tab and run the "Build Android APK (Buildozer Docker)" workflow or wait for it to run on push.
3. When the workflow completes, download the `android-apk` artifact from the workflow run (it will contain `bin/` with the APK).

Getting a signed release APK (optional)

Create a Java keystore locally (example):

```bash
keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
```

For a local release build with Buildozer, set these fields in `mobile_app/buildozer.spec` (or uncomment and update the placeholders):

```
key.store = /absolute/path/to/my-release-key.jks
key.alias = my-key-alias
key.store.password = <store-password>
key.alias.password = <alias-password>
```

To sign via CI, store the keystore as a base64-encoded GitHub secret and write it to a file in the workflow before building. Example workflow step (add before running Buildozer):

```yaml
- name: Write keystore
  if: env.SIGNING == 'true'
  run: |
    echo "$${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > my-release-key.jks
    sed -i "s|key.store = .*|key.store = $(pwd)/my-release-key.jks|" mobile_app/buildozer.spec
    sed -i "s|key.alias = .*|key.alias = $${{ secrets.KEY_ALIAS }}|" mobile_app/buildozer.spec
    sed -i "s|key.store.password = .*|key.store.password = $${{ secrets.KEYSTORE_PASSWORD }}|" mobile_app/buildozer.spec
    sed -i "s|key.alias.password = .*|key.alias.password = $${{ secrets.KEY_PASSWORD }}|" mobile_app/buildozer.spec
```

Set the following GitHub Secrets in your repo: `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD` and set an environment variable `SIGNING=true` for the workflow run.

Quick local steps I added to simplify testing and packaging

- Copy your existing workbook into the mobile app folder (so it gets bundled) by running:

```powershell
python mobile_app\copy_workbook.py
```

- Run the app on your Windows desktop with the included PowerShell helper:

```powershell
.\mobile_app\run_desktop.ps1
```

Push & CI helper

I added `push_to_github.ps1` in the repo root to create a GitHub repo, push the code, and start the CI workflow. To run:

```powershell
cd C:\Users\dell\Desktop\MyTradingApp
.\push_to_github.ps1
```

Follow the prompts to enter a repo name. The script requires `git` and the GitHub CLI `gh`.

Notes

- The `copy_workbook.py` script copies the `JOURNAL.xlsm` from the repo root into `mobile_app/` so it is included when building the APK with Buildozer.
- The `run_desktop.ps1` script creates a `.venv`, installs requirements, and launches the Kivy app for quick testing.

CI notes

- The workflow runs `mobile_app/copy_workbook.py` before invoking Buildozer so your `JOURNAL.xlsm` is bundled inside the APK and available on first run. Ensure `JOURNAL.xlsm` in the repo root is the workbook you want packaged into the APK.
- The workflow can create a GitHub Release and attach built APKs — check the Actions run for the release step and artifacts.

- The app supports SAF (Storage Access Framework) export on Android: when you choose "Export to Downloads" the app will offer a system dialog to pick a location or cloud provider — compatible with Android 11+ scoped storage. If SAF cannot be used on a device the app falls back to writing to the device Downloads folder.


