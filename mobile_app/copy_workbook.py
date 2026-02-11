from pathlib import Path
import shutil
import sys

try:
    from openpyxl import Workbook
except Exception:
    Workbook = None

HEADERS = [
    "DATE", "ENTRY TIME", "EXIT TIME", "INSTRUMENT", "STRIKE PRICE",
    "CE/PE", "BUY/SELL", "QUANTITY", "ENTRY PRICE", "EXIT PRICE",
    "STOP LOSS", "P&L"
]


def create_template(path: Path):
    if Workbook is None:
        print('openpyxl not available to create template')
        return False
    wb = Workbook()
    ws = wb.active
    ws.title = 'Sheet1'
    # Leave rows 1-8 blank, headers on row 9
    for i, h in enumerate(HEADERS, start=1):
        ws.cell(row=9, column=i, value=h)
    wb.save(str(path))
    print(f'Created template workbook at {path}')
    return True


def main():
    repo_root = Path(__file__).resolve().parents[1]
    src = repo_root / 'JOURNAL.xlsm'
    dst = Path(__file__).resolve().parent / 'JOURNAL.xlsm'

    if src.exists():
        shutil.copy2(str(src), str(dst))
        print(f'Copied {src} -> {dst}')
        return

    # If no workbook in repo root, create a template there and copy it
    print(f'No {src} found. Creating a template workbook...')
    created = create_template(src)
    if not created:
        print('Failed to create template workbook. Please add JOURNAL.xlsm to repo root manually.')
        sys.exit(1)
    shutil.copy2(str(src), str(dst))
    print(f'Copied {src} -> {dst}')


if __name__ == '__main__':
    main()
