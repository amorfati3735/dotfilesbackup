import sys
import os
import datetime
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QIntValidator, QWheelEvent, QAction, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QLineEdit, QFrame, QStackedWidget, QProgressBar, QMenu
)

# --- USER CONFIG ---
BASE_PATH = "/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
DAILY_NOTES_PATH = os.path.join(BASE_PATH, "「日常」")
SESSIONS_FILE_PATH = os.path.join(BASE_PATH, "sessions.md")

THEMES = {
    "acid_terminal": {
        "BACKGROUND": "#000000", "FRAME": "#333333",
        "MAIN_TEXT": "#D7FF3C", "SUB_TEXT": "#557711",
        "INPUT_BG": "#000000", "INPUT_BORDER": "#333333",
        "BUTTON_BG": "#111111", "BUTTON_ACTIVE_BG": "#2F3E0F", "PIN_ACTIVE": "#D7FF3C",
        "ALARM_COLOR": "#FF00FF",
        "UI_FONT": "JetBrainsMono NF",
        "TIMER_FONT": "JetBrainsMono NF", "TIMER_SIZE": "32pt",
        "OPACITY": 0.95, "BORDER_RADIUS": "0px", "BORDER_WIDTH": "2px",
        "PLACEHOLDER_TASK": "exec_task", "PLACEHOLDER_TIME": "<t>"
    },
    "ember_dark": {
        "BACKGROUND": "#0A0A12", "FRAME": "#12121A",
        "MAIN_TEXT": "#CCFFCC", "SUB_TEXT": "#88AA88",
        "INPUT_BG": "#080810", "INPUT_BORDER": "#12121A",
        "BUTTON_BG": "#2C3128", "BUTTON_ACTIVE_BG": "#364921", "PIN_ACTIVE": "#99FF00",
        "ALARM_COLOR": "#FF3333",
        "UI_FONT": "Cantarell", "TIMER_FONT": "CaskaydiaCove NFM", "TIMER_SIZE": "34pt",
        "OPACITY": 1.0, "BORDER_RADIUS": "12px", "BORDER_WIDTH": "1px",
        "PLACEHOLDER_TASK": ">..code", "PLACEHOLDER_TIME": "min"
    },
    "minimal_gothic": {
        "BACKGROUND": "#0A0A0B", "FRAME": "#161617",
        "MAIN_TEXT": "#E6E0D8", "SUB_TEXT": "#7A7370",
        "INPUT_BG": "#0A0A0B", "INPUT_BORDER": "#161617",
        "BUTTON_BG": "#151518", "BUTTON_ACTIVE_BG": "#3A1F2A", "PIN_ACTIVE": "#E6E0D8",
        "ALARM_COLOR": "#8C1B3A",
        "UI_FONT": "Cantarell", "TIMER_FONT": "Cantarell", "TIMER_SIZE": "32pt",
        "OPACITY": 0.95, "BORDER_RADIUS": "0px", "BORDER_WIDTH": "2px",
        "PLACEHOLDER_TASK": "exec_task", "PLACEHOLDER_TIME": "<t>"
    }
}


class ModernTimerApp(QWidget):
    def __init__(self):
        super().__init__()

        self.seconds_value = 0
        self.initial_seconds = 0
        self.is_running = False
        self.flash_state = False
        self.session_logged = False

        self.theme_names = list(THEMES.keys())
        self.current_theme_index = 0

        self.setWindowTitle("timer")
        self.resize(240, 220)

        self._init_ui()
        self._setup_shortcuts()

        self.main_timer = QTimer(self)
        self.main_timer.setInterval(1000)
        self.main_timer.timeout.connect(self._update_timer)

        self.alarm_timer = QTimer(self)
        self.alarm_timer.setInterval(500)
        self.alarm_timer.timeout.connect(self._flash_alarm)

        self._apply_theme()

    def _get_current_theme(self):
        return THEMES[self.theme_names[self.current_theme_index]]

    def _setup_shortcuts(self):
        QShortcut(QKeySequence("Space"), self).activated.connect(self._toggle_timer)
        QShortcut(QKeySequence("Esc"), self).activated.connect(self.showMinimized)

    def _init_ui(self):
        self.central_frame = QFrame(self)
        self.central_frame.setObjectName("centralFrame")

        main_layout = QVBoxLayout(self.central_frame)
        main_layout.setContentsMargins(12, 8, 12, 12)
        main_layout.setSpacing(6)

        # Header
        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)

        self.theme_btn = QPushButton("🌙")
        self.theme_btn.setObjectName("iconBtn")
        self.theme_btn.clicked.connect(self._cycle_theme)

        header.addWidget(self.theme_btn)
        header.addStretch()

        main_layout.addLayout(header)

        # Input area
        self.input_stack = QStackedWidget()
        self.input_stack.setFixedHeight(30)

        pg0 = QWidget()
        l0 = QHBoxLayout(pg0)
        l0.setContentsMargins(0, 0, 0, 0)
        l0.setSpacing(5)

        self.task_input = QLineEdit()
        self.task_input.setObjectName("taskInput")

        self.time_input = QLineEdit()
        self.time_input.setValidator(QIntValidator(1, 999))
        self.time_input.setFixedWidth(45)
        self.time_input.setAlignment(Qt.AlignCenter)
        self.time_input.setObjectName("timeInput")
        self.time_input.setContextMenuPolicy(Qt.CustomContextMenu)
        self.time_input.customContextMenuRequested.connect(self._show_time_presets)

        l0.addWidget(self.task_input)
        l0.addWidget(self.time_input)

        self.task_label = QLabel()
        self.task_label.setAlignment(Qt.AlignCenter)
        self.task_label.setObjectName("taskLabel")

        self.input_stack.addWidget(pg0)
        self.input_stack.addWidget(self.task_label)
        main_layout.addWidget(self.input_stack)

        main_layout.addStretch(1)

        # Timer display
        timer_layout = QVBoxLayout()
        timer_layout.setSpacing(0)

        self.timer_val_label = QLabel("00:00:00")
        self.timer_val_label.setAlignment(Qt.AlignCenter)
        self.timer_val_label.setObjectName("timerDigits")

        sub_layout = QHBoxLayout()
        for txt in ["H", "M", "S"]:
            lbl = QLabel(txt)
            lbl.setObjectName("subLabel")
            lbl.setAlignment(Qt.AlignCenter)
            sub_layout.addWidget(lbl)

        timer_layout.addWidget(self.timer_val_label)
        timer_layout.addLayout(sub_layout)
        main_layout.addLayout(timer_layout)

        # Progress
        self.progress_bar = QProgressBar()
        self.progress_bar.setFixedHeight(2)
        self.progress_bar.setTextVisible(False)
        self.progress_bar.setObjectName("progressBar")
        self.progress_bar.setValue(0)
        main_layout.addWidget(self.progress_bar)

        main_layout.addStretch(1)

        # Controls
        controls = QHBoxLayout()
        controls.setAlignment(Qt.AlignCenter)
        controls.setSpacing(12)

        self.btn_reset = QPushButton("Reset")
        self.btn_reset.setFixedSize(65, 34)
        self.btn_reset.setObjectName("pillBtn")
        self.btn_reset.clicked.connect(self._reset_timer)

        self.btn_start = QPushButton("Start")
        self.btn_start.setFixedSize(80, 34)
        self.btn_start.setObjectName("pillBtnMain")
        self.btn_start.clicked.connect(self._toggle_timer)

        controls.addStretch()
        controls.addWidget(self.btn_reset)
        controls.addWidget(self.btn_start)
        controls.addStretch()
        main_layout.addLayout(controls)

        outer_layout = QVBoxLayout(self)
        outer_layout.setContentsMargins(0, 0, 0, 0)
        outer_layout.addWidget(self.central_frame)

    def _show_time_presets(self, pos):
        menu = QMenu(self)
        menu.setStyleSheet(
            "QMenu { background-color: #222; color: #FFF; border: 1px solid #555; }"
            "QMenu::item:selected { background-color: #444; }"
        )
        for p in [5, 15, 25, 45, 60]:
            action = QAction(f"{p} min", self)
            action.triggered.connect(lambda checked, x=p: self.time_input.setText(str(x)))
            menu.addAction(action)
        menu.exec(self.time_input.mapToGlobal(pos))

    def _cycle_theme(self):
        self.current_theme_index = (self.current_theme_index + 1) % len(self.theme_names)
        self._apply_theme()

    def _apply_theme(self):
        t = self._get_current_theme()

        self.setWindowOpacity(t.get("OPACITY", 1.0))
        self.task_input.setPlaceholderText(t["PLACEHOLDER_TASK"])
        self.time_input.setPlaceholderText(t["PLACEHOLDER_TIME"])

        css = f"""
            QWidget {{ font-family: '{t['UI_FONT']}'; }}

            #centralFrame {{
                background-color: {t['BACKGROUND']};
                border: {t['BORDER_WIDTH']} solid {t['FRAME']};
                border-radius: {t['BORDER_RADIUS']};
            }}

            #iconBtn {{
                background: transparent; color: {t['SUB_TEXT']};
                font-size: 14px; font-weight: bold; border: none;
            }}
            #iconBtn:hover {{ color: {t['MAIN_TEXT']}; }}

            QLineEdit {{
                background-color: {t['INPUT_BG']}; border: 1px solid {t['INPUT_BORDER']};
                border-radius: 4px; color: {t['MAIN_TEXT']}; padding: 2px 5px; font-size: 12px;
            }}
            QLineEdit:focus {{ border: 1px solid {t['PIN_ACTIVE']}; }}

            #taskLabel {{ color: {t['MAIN_TEXT']}; font-weight: bold; font-size: 13px; }}

            #timerDigits {{
                font-family: '{t['TIMER_FONT']}'; font-size: {t['TIMER_SIZE']};
                color: {t['MAIN_TEXT']}; font-weight: bold;
            }}
            #timerDigits[alarm="true"] {{ color: {t['ALARM_COLOR']}; }}

            #subLabel {{ color: {t['SUB_TEXT']}; font-size: 9px; font-weight: bold; letter-spacing: 1px; }}

            QProgressBar {{
                background-color: {t['FRAME']}; border: none; border-radius: 1px;
            }}
            QProgressBar::chunk {{
                background-color: {t['PIN_ACTIVE']}; border-radius: 1px;
            }}

            #pillBtn {{
                background-color: {t['BUTTON_BG']}; color: {t['MAIN_TEXT']};
                border: none; border-radius: 6px; font-weight: bold;
            }}
            #pillBtn:hover {{ background-color: {t['FRAME']}; }}

            #pillBtnMain {{
                background-color: {t['BUTTON_ACTIVE_BG']}; color: {t['MAIN_TEXT']};
                border: none; border-radius: 6px; font-weight: bold;
            }}
            #pillBtnMain:hover {{ background-color: {t['BUTTON_BG']}; }}
        """
        self.central_frame.setStyleSheet(css)

    def _toggle_timer(self):
        if not self.is_running:
            if self.initial_seconds == 0:
                try:
                    mins = int(self.time_input.text())
                    if mins <= 0:
                        return
                except ValueError:
                    return

                self.initial_seconds = mins * 60
                self.seconds_value = self.initial_seconds
                self.session_logged = False

                txt = self.task_input.text().strip()
                self.task_label.setText(txt if txt else "Untitled")
                self.input_stack.setCurrentIndex(1)

                self.btn_start.setText("Pause")
                self.progress_bar.setValue(100)

                self.main_timer.start()
                self.is_running = True
            else:
                self.main_timer.start()
                self.is_running = True
                self.btn_start.setText("Pause")
        else:
            self.main_timer.stop()
            self.alarm_timer.stop()
            self.is_running = False
            self.btn_start.setText("Resume")

    def _reset_timer(self):
        self.main_timer.stop()
        self.alarm_timer.stop()
        self.is_running = False
        self.seconds_value = 0
        self.initial_seconds = 0
        self.flash_state = False

        self.btn_start.setText("Start")
        self.input_stack.setCurrentIndex(0)
        self.task_input.clear()
        self.time_input.clear()
        self.progress_bar.setValue(0)

        self.timer_val_label.setProperty("alarm", False)
        self.style().polish(self.timer_val_label)
        self.timer_val_label.setText("00:00:00")

    def _update_timer(self):
        self.seconds_value -= 1

        if self.initial_seconds > 0:
            pct = int((self.seconds_value / self.initial_seconds) * 100)
            self.progress_bar.setValue(max(0, pct))

        if self.seconds_value == 0:
            QApplication.beep()
            self.alarm_timer.start()
        elif self.seconds_value < 0 and not self.alarm_timer.isActive():
            self.alarm_timer.start()

        self._update_display()

    def _flash_alarm(self):
        self.flash_state = not self.flash_state
        self.timer_val_label.setProperty("alarm", self.flash_state)
        self.style().polish(self.timer_val_label)

    def _update_display(self):
        is_neg = self.seconds_value < 0
        total_sec = abs(self.seconds_value)
        h, rem = divmod(total_sec, 3600)
        m, s = divmod(rem, 60)
        prefix = "-" if is_neg else ""
        self.timer_val_label.setText(f"{prefix}{h:02d}:{m:02d}:{s:02d}")

    # --- LOGGING ---
    def closeEvent(self, event):
        if self.initial_seconds > 0 and not self.session_logged:
            self._perform_logging()
        event.accept()

    def _perform_logging(self):
        elapsed = self.initial_seconds - self.seconds_value
        mins = max(1, elapsed // 60)
        task_name = self.task_label.text() or "Untitled"

        try:
            self._log_to_day_note(task_name, mins)
            self._log_to_sessions_table(task_name, mins)
            self.session_logged = True
            print(f"Logged {mins} mins for '{task_name}'")
        except Exception as e:
            print(f"Logging Failed: {e}")

    def _log_to_day_note(self, task, mins):
        today = datetime.date.today()
        fname = today.strftime("%d-%b.md")
        fpath = os.path.join(DAILY_NOTES_PATH, fname)
        log_line = f"- [{task} - {mins}min]"

        os.makedirs(DAILY_NOTES_PATH, exist_ok=True)

        content = ""
        if os.path.exists(fpath):
            with open(fpath, 'r', encoding='utf-8') as f:
                content = f.read()

        if "## Sessions" not in content:
            new_entry = f"\n\n## Sessions\n{log_line}"
        else:
            new_entry = f"\n{log_line}"

        with open(fpath, 'a', encoding='utf-8') as f:
            f.write(new_entry)

    def _log_to_sessions_table(self, task, mins):
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

    # --- WINDOW EVENTS ---
    def wheelEvent(self, e: QWheelEvent):
        if QApplication.keyboardModifiers() == Qt.ControlModifier:
            delta = e.angleDelta().y()
            current_op = self.windowOpacity()
            new_op = min(current_op + 0.05, 1.0) if delta > 0 else max(current_op - 0.05, 0.2)
            self.setWindowOpacity(new_op)
            e.accept()
        else:
            super().wheelEvent(e)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    win = ModernTimerApp()
    win.show()
    sys.exit(app.exec())
