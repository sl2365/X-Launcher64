# X-Launcher 64

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

# Build layout and instructions

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
        BUILD.bat
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

Both build files use relative paths only.

Important:

- AutoIt3_x64.exe is the interpreter, not the compiler.
- Aut2Exe performs compilation.
- AutoIt3Wrapper is retained only as a command-line build utility because the current x-compiler.au3 uses AutoIt3Wrapper directives for resource metadata, automatic FileVersion incrementing, DPI/manifest settings, etc.

ISN Studio and the SciTE/AutoIt editor are not required to build X-Launcher64 v2.

- Double-click `BUILD.bat` for AU3Check and compilation only. The compiled launcher remains as `X-Launcher_x64.exe` in the project root.
- Double-click `BUILD_TEST.bat` for AU3Check, compilation, and all 55 permanent regression tests. This build moves the compiled launcher to `Test_Suite\X-Launcher_x64.exe` and writes `Test_Suite\Results.log`.
- Double-click `Test_Suite\RUN_TEST.bat` to rerun the permanent suite against the test launcher already present.

---

# Configuration compatibility

All added settings are optional. Existing INI files remain valid and keep their previous behavior when the new keys are absent.

## Registry view

Existing configurations continue using the launcher's native registry view unless `RegView` is specified. New configurations use `RegView=Auto`, which selects the registry view from the launched application's architecture. Existing portable applications that use registry redirection and were previously run with a 32-bit X-Launcher may need `RegView=32` added once.

| Setting | Result |
|---|---|
| Key absent | Launcher-native view |
| `RegView=32` | Force 32-bit view |
| `RegView=64` | Force 64-bit view |
| `RegView=Native` | Force launcher-native view |
| `RegView=Auto` | Use the target EXE's 32-bit or 64-bit view; fall back to Native when it cannot be detected |

## Java

`Java` controls whether the application requires Java:

| Setting | Result |
|---|---|
| `Java=false` | Do not use Java. A saved `JavaPath` is retained but ignored. |
| `Java=true` | Require a usable Java runtime; stop with an error if none can be resolved. |
| `Java=optional` | Use Java when available, but allow the application to continue without it. |

`JavaPath` is the highest-priority, read-only runtime source. It accepts an absolute path or a path relative to `Root`, including a Java runtime root, its `bin` folder, `java.exe`, or `javaw.exe`. Quotes are accepted. A valid runtime must contain both `java.exe` and `javaw.exe`. Point this setting at a full jPortable/PortableApps Java or Java64 runtime, not at `JavaPortableLauncher.exe`.

Examples:

```ini
Java=true
JavaPath=D:\SyMenu\ProgramFiles\PA.c\PortableApps\CommonFiles\Java64
```

```ini
Java=optional
JavaPath=.\CommonFiles\Java\bin\javaw.exe
```

`JavaURL` remains an optional direct HTTP or HTTPS Java package URL. It is a download/setup fallback used only when Java is enabled and no usable configured, bundled, or system runtime was found. Local paths belong in `JavaPath`, not `JavaURL`.

---

# Built-in diagnostics

The diagnostics are deliberately split by risk. Set `TestRun` in `[Options]`, save the INI, and launch X-Launcher normally. A non-false value is confirmed before it runs. Restore `TestRun=false` afterwards or the prompt will appear on every launch.

| Setting | Mode | Effect |
|---|---|---|
| missing, blank, or `TestRun=false` | Normal | Launch the configured application normally. |
| `TestRun=Probe` | Configuration Probe | Read-only checks; does not launch the configured application or run configured operations. |
| `TestRun=Trace` | Application Trace | Launches the real configured application and performs its configured operations. Process Monitor capture is optional. |
| `TestRun=Full` | Full Test | Runs the isolated built-in self-test without the configured application, real Java setup, or Process Monitor. |

Advanced users can start the launcher with `--x-launcher-test` to choose a mode for the current process without editing the INI.

## Configuration Probe

Probe validates the launcher configuration without changing the configured target. Its report is written to:

```text
Diagnostics\<LauncherName>_Configuration_Probe_<timestamp>_<pid>.txt
```

The interactive run opens the report when complete.

## Application Trace

Trace is not read-only. It launches the actual configured application and runs the configured file, registry, environment, and other operations. Each run creates:

```text
Diagnostics\<AppName>\<timestamp_millisecond_pid>\
    Application_Trace_Summary.txt
    X-Launcher_Settings.log
    X-Launcher_Debug.dbg
    Application_Trace.pml       (only when native capture is saved)
```

`ProcMonPath` may contain the Process Monitor executable or its folder. Absolute paths and paths relative to `Root` are accepted. If blank, X-Launcher tries `$Lib$\Tools\ProcessMonitor\Procmon64.exe`. Supported executable names are `Procmon64.exe`, `Procmon.exe`, and `Procmon64a.exe`, selected for the operating-system architecture.

X-Launcher does not download Process Monitor, silently accept its licence, or take over an existing Process Monitor session. Starting native capture can display UAC and first-run licence prompts. If Process Monitor is unavailable, Trace offers an X-Launcher-only report or cancellation.

The optional PML safeguards default to `ProcMonMaxMB=512` and `ProcMonReserveMB=1024`. Accepted values are 64-102400 MB and 256-102400 MB respectively. Capture is stopped and preserved as partial evidence if a limit is reached.

## Full Test

Full Test is independent of configured targets and can run even when the normal INI is unavailable. It uses an isolated `%TEMP%\X-Launcher-SelfTest\<session>` workspace and dedicated HKCU test roots. It does not run the configured application or operations, download/use a real Java runtime, start Process Monitor, or request elevation.

The report is written below `Diagnostics\X-Launcher-SelfTest\<session>\Full_Test_Report.txt`. A successful temporary workspace is removed. A failed workspace is preserved and its path is shown so it can be inspected. The built-in test complements the permanent external regression suite; it does not replace it.

## Debug logging

`Debug=true` enables the normal application diagnostic stream. It also enables the launcher log even when `WriteLog=false`:

```text
<LauncherName>.dbg
<LauncherName>.log
```

Diagnostic results use `PASS`, `FAIL`, `WARN`, `SKIP`, and `NOT USED` classifications.

## Limits and privacy

X-Launcher-only Trace evidence can report launcher operations and launch/process results, but it cannot observe all activity performed later by an application. Even a native Process Monitor capture cannot automatically decide whether every change is residue or intended behavior. Attribution can be incomplete for services, brokers, elevated processes, and short-lived child processes. Writes outside `Root` are warnings for review, not automatic proof of failure.

Reports, `.log`, `.dbg`, and `.pml` files can contain usernames, paths, command lines, document names, registry data, and other private information. Review them before sharing and delete diagnostic output when it is no longer needed.

---

| Component | Intended user | Purpose |
|---|---|---|
| Test_Suite	| Developer/maintainer	| Proves the audit repairs haven’t broken anything. Its 55 tests validate X-Launcher code.|
| Debug_Feature_Test_Kit	| Developer/maintainer	| Proves the newly built diagnostic features themselves work correctly. It is not for testing normal applications.|
| Built-in TestRun modes	| Ordinary X-Launcher user	| Tests X-Launcher itself or a user’s real application INI.|

# Remaining ideas

- `FixProgramData=true/false`
- `FixProgramFiles32=true/false`
- `FixProgramFiles64=true/false`
- `FixUserDocs=true/false`
- `FixPublicDocs=true/false`