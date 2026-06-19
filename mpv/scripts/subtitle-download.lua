local utils = require "mp.utils"

local function download_subtitles()
    local path = mp.get_property("path")
    if not path then
        mp.osd_message("No file playing", 2)
        return
    end

    local abs_path = path
    if not path:match("^/") then
        abs_path = utils.join_path(utils.getcwd(), path)
    end

    mp.osd_message("Downloading subtitles...", 60)

    local venv_python = os.getenv("HOME") .. "/.local/share/mpv-scripts-venv/bin/python"
    local cmd = {
        venv_python, "-m", "subliminal", "download", "-l", "eng",
        "--", abs_path
    }

    local res = utils.subprocess({args = cmd, cancellable = false})

    if res.status == 0 then
        mp.osd_message("Subtitles downloaded!", 2)
        mp.command("rescan_external_files")
        mp.command("sub-reload")
    elseif res.status == 17 then
        mp.osd_message("No subtitles found", 2)
    else
        mp.osd_message("Subtitle download failed", 2)
    end
end

mp.add_key_binding("s", "download-subtitles", download_subtitles)
mp.osd_message("Press s to download subtitles", 3)
