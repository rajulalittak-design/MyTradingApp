
[app]
title = TradingJournal
package.name = tradingjournal
package.domain = org.example
source.include_exts = py,kv,xlsm
source.dir = .
version = 0.1
requirements = python3,kivy==2.2.1,openpyxl,plyer,pyjnius
orientation = portrait
android.permissions = WRITE_EXTERNAL_STORAGE,READ_EXTERNAL_STORAGE
android.minapi = 21
android.api = 31
android.ndk = 23b
presplash.filename = %(source.dir)s/data/presplash.png

# Release signing (example placeholders)
# To build a signed release APK, create a keystore and set these values.
# key.store = /path/to/keystore.jks
# key.alias = my-key-alias
# key.store.password = <store-password>
# key.alias.password = <alias-password>

[buildozer]
log_level = 2
warn_on_root = 1

