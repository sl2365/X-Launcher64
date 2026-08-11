# X-Launcher 64

[![Release](https://img.shields.io/github/v/release/sl2365/X-Launcher64?style=for-the-badge-square&color=olive)](https://github.com/sl2365/X-Launcher64/releases/latest/download/X-Launcher64.zip)
[![Release Date](https://img.shields.io/github/release-date/sl2365/X-Launcher64?style=for-the-badge-square&color=yellow)](https://github.com/sl2365/X-Launcher64/releases)

Updated version of the portable launcher. Want to make your apps portable? Use X-Launchers easy to use yet advanced capabilities!

For a quicker response to issues, please post bug reports and FR's on the [PortableFreeware](https://www.portablefreeware.com/forums/viewtopic.php?t=26375) forum.

Compiled with AutoIT v3.3.18.0

![jpg X-Splash](graphics/x-splash.jpg)

### NOTE:
AutoIT v3.3.18.0 has discontinued support for older Windows versions: XP and Vista.
AutoIT v3.3.18.0 only supports Windows 7 and later.
See the [AutoIT changelog](https://www.autoitscript.com/autoit3/docs/history.htm) for more info. 

X-Launcher v1.5.7.20 still supports those versions.
X-Launcher v2.x.x only supports Windows 8 and later.

---

# Build layout + Instructions
Required layout
```
_Projects\
    _Tools\
        AutoIT\
            - 3.3.18.0\
                AutoIt3_x64.exe
                Aut2Exe\
                    Aut2exe_x64.exe
                Include\
                ...normal AutoIt portable files...

            AutoIt3Wrapper\
                ...copy the COMPLETE AutoIt3Wrapper utility folder here...

    X-Launcher_x64\
        BUILD_TEST.bat
        x-compiler.au3
        x-launcher.au3
        x-registry.au3
        x-udf.au3
        x-launcher.ini
        image_get_size.au3
        files\
        graphics\
        Test_Suite\
            RUN_TEST.bat
            Configs\
            Helpers\
```
BUILD_TEST.bat uses relative paths only.

Important:
- AutoIt3_x64.exe is the interpreter, not the compiler.
- Aut2Exe performs compilation.
- AutoIt3Wrapper is retained only as a command-line build utility because the current x-compiler.au3 uses AutoIt3Wrapper directives for resource metadata, automatic FileVersion incrementing, DPI/manifest settings, etc.

ISN Studio and SciTE/AutoIt editor are not required to build X-Launcher64 v2. Just run the BUILD_TEST.bat file, making sure you've set up the locations as above.

---

# New INI Settings
### New Reg Setting:
Existing configurations continue using the launcher's native registry view unless RegView is specified. New configurations use `RegView=Auto`, which automatically selects the registry view from the launched application's architecture. Existing portable applications that use registry redirection and were previously run with a 32-bit X-Launcher may need RegView=32 added once.

| Setting | Result |
|---|---|
| None  |-> Native|
| RegView=32          |-> force 32-bit|
| RegView=64          |-> force 64-bit|
| RegView=Native      |-> force launcher-native view|
| RegView=Auto        |-> Auto detect target EXE bitness each launch:<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;32-bit EXE -> 32-bit view<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;64-bit EXE -> 64-bit view<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Undetectable/non-EXE -> Native|

### New JavaURL Setting:
This is for specifying the URL to download and thus allows X-Launcher to install Java into it's folder for use by the specified app. This is a user setting rather than using the hardcoded default laid out in the original. This allows it to be updated should the Java site change or move location.
