from pathlib import Path

p = Path('/home/user/.venv/lib/python3.12/site-packages/buildozer/__init__.py')
if p.exists():
    s = p.read_text()
    old = "cont = input('Are you sure you want to continue [y/n]? ')"
    if old in s:
        s = s.replace(old, "cont = 'y'")
        p.write_text(s)
        print('patched buildozer __init__.py')
    else:
        print('pattern not found in', p)
else:
    print('buildozer __init__.py not found at', p)
