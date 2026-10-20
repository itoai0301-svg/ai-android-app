"""End-to-end tests against the installed APK through real Android touch events."""
import json, pathlib, subprocess, time, re, struct
from PIL import Image
ROOT = pathlib.Path("out")
PACKAGE = "com.sam.antmeadow"
checks = []
def adb(*args, binary=False):
    return subprocess.check_output(["adb", *args], text=not binary)
def logs():
    return adb("logcat", "-d", "-s", "godot:V", "AndroidRuntime:E")
def wait_for(marker, count=1, limit=65):
    end=time.monotonic()+limit
    while time.monotonic()<end:
        output=logs()
        if output.count(marker)>=count:
            checks.append(marker)
            print("PASS:", marker, flush=True)
            return
        if "FATAL EXCEPTION" in output or "SCRIPT ERROR" in output:
            raise AssertionError(output[-6000:])
        time.sleep(.5)
    raise AssertionError("No marker: "+marker+"\n"+logs()[-6000:])
def shot(name):
    end=time.monotonic()+50
    while time.monotonic()<end:
        data=adb("exec-out", "screencap", "-p", binary=True)
        p=ROOT/name
        p.write_bytes(data)
        im=Image.open(p).convert("RGB")
        if im.width>im.height and len(im.getcolors(im.width*im.height) or [])>1000:
            return im.size
        output=logs()
        if re.search(r"SCRIPT ERROR|Parse Error|FATAL EXCEPTION|^.*godot.*ERROR:",output,re.M):
            raise AssertionError(output[-6000:])
        time.sleep(1)
    raise AssertionError("The complete landscape scene did not render")
def tap_normalized(x, y):
    adb("shell", "input", "tap", str(round(x*width)), str(round(y*height)))
try:
    adb("install", "-r", str(ROOT/"AntMeadow-emulator.apk"))
    checks.append("APK installs successfully")
    adb("logcat", "-c")
    adb("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
    adb("shell", "am", "start", "-n", PACKAGE+"/com.godot.game.GodotAppLauncher")
    wait_for("ANT_STATE:menu")
    time.sleep(9)
    width,height=shot("android-menu.png")
    tap_normalized(.22,.60)
    wait_for("ANT_STATE:playing")
    time.sleep(1)
    shot("android-playing.png")
    targets=json.loads((ROOT/"gameplay-tests.json").read_text())["touch_targets"]
    tap_normalized(*targets["food0"])
    wait_for("ANT_PICKUP:0")
    shot("android-carrying.png")
    tap_normalized(*targets["home"])
    wait_for("ANT_DELIVER:1")
    tap_normalized(*targets["burst"])
    wait_for("ANT_BURST")
    tap_normalized(.96,.07)
    wait_for("ANT_STATE:paused")
    tap_normalized(*targets["resume"])
    wait_for("ANT_RESUMED:10")
    wait_for("ANT_STATE:playing", count=2)
    adb("shell","input","keyevent","KEYCODE_HOME")
    wait_for("ANT_STATE:paused", count=2)
    adb("shell","am","start","-n",PACKAGE+"/com.godot.game.GodotAppLauncher")
    time.sleep(2)
    tap_normalized(*targets["resume"])
    wait_for("ANT_RESUMED:10",count=2)
    wait_for("ANT_STATE:playing",count=3)
    assert adb("shell","pidof",PACKAGE).strip()
    checks.append("App survives background and resume")
    output=logs()
    (ROOT/"android-log.txt").write_text(output)
    assert not re.search(r"SCRIPT ERROR|Parse Error|FATAL EXCEPTION|signal 11|^.*godot.*ERROR:",output,re.M), output[-6000:]
    checks.append("No Godot script errors or Android crashes")
    report={"status":"PASS","checks":checks,"screen":[width,height],"android_api":adb("shell","getprop","ro.build.version.sdk").strip()}
    (ROOT/"android-tests.json").write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2),flush=True)
finally:
    (ROOT/"android-log.txt").write_text(logs())

