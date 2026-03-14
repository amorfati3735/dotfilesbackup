#!/usr/bin/env python3
import sys
import os
import argparse
import datetime

# --- CONFIG ---
BASE_PATH = os.path.join(os.path.expanduser("~"), "Dropbox", "DropsyncFiles", "lesser amygdala")
DAILY_NOTES_PATH = os.path.join(BASE_PATH, "「日常」")
SESSIONS_FILE_PATH = os.path.join(BASE_PATH, "sessions.md")

def log_to_day_note(task, mins):
    today = datetime.date.today()
    fname = today.strftime("%d-%b.md")
    fpath = os.path.join(DAILY_NOTES_PATH, fname)
    
    log_line = f"- [{task} - {mins}min]"
    content = ""
    
    os.makedirs(DAILY_NOTES_PATH, exist_ok=True)

    if os.path.exists(fpath):
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()

    if "## Sessions" not in content:
        new_entry = f"\n\n## Sessions\n{log_line}"
    else:
        new_entry = f"\n{log_line}"
        
    with open(fpath, 'a', encoding='utf-8') as f:
        f.write(new_entry)

def log_to_sessions_table(task, mins):
    fpath = SESSIONS_FILE_PATH
    today_str = datetime.date.today().strftime("[%d-%b]")
    
    task_row_str = f"| - [{task} - {mins}min] | |"
    date_row_str = f"| {today_str} | |"
    
    lines = []
    if os.path.exists(fpath):
        with open(fpath, 'r', encoding='utf-8') as f:
            lines = f.read().splitlines()
    else:
        lines = ["| | |", "| --- | --- |"]

    if len(lines) < 2:
        lines = ["| | |", "| --- | --- |"]

    if len(lines) > 2 and lines[2].strip() == date_row_str:
        lines.insert(3, task_row_str)
    else:
        lines.insert(2, date_row_str)
        lines.insert(3, task_row_str)
        
    with open(fpath, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--task", required=True, help="Name of the task")
    parser.add_argument("--mins", required=True, type=int, help="Minutes elapsed")
    args = parser.parse_args()

    task_name = args.task.strip()
    if not task_name:
        task_name = "Untitled"
        
    try:
        log_to_day_note(task_name, args.mins)
        log_to_sessions_table(task_name, args.mins)
        print(f"Successfully logged {args.mins} mins for '{task_name}'")
    except Exception as e:
        print(f"Logging Failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
