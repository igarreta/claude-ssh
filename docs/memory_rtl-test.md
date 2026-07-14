---
name: project_docker03_rtl-test
description: docker03 has an unused RTL-SDR dongle; in-progress attempt to capture a garage door opener's 433MHz signature
metadata:
  type: project
---

docker03 has an RTL2838 RTL-SDR dongle (Realtek, `0bda:2838`) attached but otherwise unused (USB path `/dev/bus/usb/002/002`). Goal: capture the RF signature of a garage door opener remote.

**Why:** Want to identify/replay the garage opener's signal (or at least confirm what protocol/frequency it uses).

**Setup used (2026-07-12):**
- No native `rtl_433`/`rtl_sdr` binaries installed on docker03 host — used Docker instead.
- Image `hertzg/rtl_433:latest` was already pulled locally on docker03 (11.2MB).
- USB passthrough: `docker run -d --name rtl433-capture --device=/dev/bus/usb -v /dev/bus/usb:/dev/bus/usb hertzg/rtl_433:latest <args>` — works without `--privileged`.
- Default frequency 433.92MHz matches typical EU garage remotes.
- Ran in pulse-analyzer mode (`-A -f 433920000`) since garage remotes are frequently proprietary/rolling-code (KeeLoq etc.) and not decoded by rtl_433's built-in device list — analyzer mode dumps raw pulse timing instead of requiring a known decoder.

**Problem hit:** `-A` mode floods the log with ambient RF noise (thousands of lines within ~30s), even with `-Y squelch -Y autolevel`. Tracking "new lines since a marker" via `docker logs | wc -l` was unreliable — line counts didn't advance as expected between calls (buffering, not truncation, as best as verified). Session was paused before a clean button-press capture was completed; container was stopped/removed (`docker rm -f rtl433-capture`) at end of session.

**How to apply / next steps:**
- Restart with the same `docker run` command above.
- Instead of counting lines, use `docker logs --since <ISO timestamp> --timestamps` right after telling the user to press the remote, to isolate just that window.
- Consider raising the squelch/level manually (`-Y level=<dB>` or `-Y minlevel=`) rather than autolevel, since ambient noise on 433.92MHz was still triggering the analyzer.
- If analyzer noise remains unmanageable, try `-S all` (auto-save each detected signal to its own timestamped file) instead of streaming text — makes it easier to correlate by file mtime around the button press rather than parsing a noisy log stream.
