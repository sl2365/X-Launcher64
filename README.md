# X-Launcher 64

[![Release](https://img.shields.io/github/v/release/sl2365/X-Launcher64?style=for-the-badge-square&color=olive)](https://github.com/sl2365/X-Launcher64/releases/latest/download/X-Launcher64.rar)
[![Release Date](https://img.shields.io/github/release-date/sl2365/X-Launcher64?style=for-the-badge-square&color=yellow)](https://github.com/sl2365/X-Launcher64/releases)

[![Commits Since Release](https://img.shields.io/github/commits-since/sl2365/X-Launcher64/latest?style=for-the-badge-square&color=green)](https://github.com/sl2365/X-Launcher64/activity)
[![Last Commit](https://img.shields.io/github/last-commit/sl2365/X-Launcher64?style=for-the-badge-square&color=green)](https://github.com/sl2365/X-Launcher64/activity)

Updated version of the portable launcher. Want to make your apps portable? Use X-Launchers easy to use yet advanced capabilities!

For a quicker response to issues, please post bug reports and FR's on the [PortableFreeware](https://www.portablefreeware.com/forums/viewtopic.php?t=26375) forum.

Compiled with AutoIT v3.3.18.0

![jpg X-Splash](graphics/x-splash.jpg)

### NOTE:
AutoIT v3.3.18.0 has discontinued support for older Windows versions: XP and Vista, only supports Windows 7 and later.
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
- Double-click `BUILD_TEST.bat` for AU3Check, compilation, and all 66 permanent regression tests. This build moves the compiled launcher to `Test_Suite\X-Launcher_x64.exe` and writes `Test_Suite\Results.log`.
- Double-click `Test_Suite\RUN_TEST.bat` to rerun the permanent suite against the test launcher already present.

---

# Configuration compatibility

All added settings are optional. Existing INI files remain valid and keep their previous behavior when the new keys are absent.

## Portable application-data and temporary folders

The `[Environment]` section sets process environment variables for X-Launcher, the application it starts, and child processes. Each entry is a variable name and value. X-Launcher path variables such as `$Lib$` can be used in the value.

For the common Windows folders, two optional `[Options]` settings provide simpler defaults:

| Setting | Environment produced before launch |
|---|---|
| `FixLocalAppData=true` | Creates `$Lib$\AppData\Local` and sets `LOCALAPPDATA` to it. |
| `FixTemp=true` | Creates `$Lib$\AppData\Local\Temp` and sets both `TEMP` and `TMP` to it. |

Both settings default to `false`, are independent, and do not require a separate `FixTmp` option. If the same variable is explicitly present in `[Environment]`, that explicit value is processed afterwards and takes priority.

The older `FixAppData` option is separate and is activated while X-Launcher processes a configured `USERPROFILE` entry. With `FixAppData=true` and `USERPROFILE=$Lib$`, `APPDATA` becomes `$Lib$\<the host Roaming folder name>`. It also maintains localized Desktop, Documents and Favorites child names. It does not redirect `LOCALAPPDATA`, `TEMP`, `TMP`, or the Windows LocalLow known folder. `FixLocalAppData=true` handles `LOCALAPPDATA`; Windows has no equivalent LocalLow environment variable. An application that constructs LocalLow from `%USERPROFILE%` may follow the portable profile, but an application using the Windows LocalLow known-folder API may not.

`FixAppData` can safely be combined with both new options; X-Launcher captures the Windows shell-folder names before applying the portable environment. Unsafe child-folder names, including names containing control characters, are rejected before a directory can be renamed or created. Explicit `[Environment]` values are still processed afterwards and take priority.

`FixTemp` does not delete the portable folder. It is unrelated to `[FileSystem] Temp` and `DeleteTemp`, which control X-Launcher’s own working temp. To remove the application’s portable temp after it closes, use the existing internal cleanup operation, for example:

```ini
[RunAfter]
DirRemove=$Lib$\AppData\Local\Temp
```

The equivalent advanced configuration remains valid:

```ini
[Environment]
LOCALAPPDATA=$Lib$\AppData\Local
TEMP=$Lib$\AppData\Local\Temp
TMP=$Lib$\AppData\Local\Temp
```

## Junctions and symbolic links

`[Functions]` can create a directory junction or a file/directory symbolic link before the application starts. The first path is the existing target and the second path is the new link:

```ini
[Functions]
Junctions=C:\ExistingData|C:\ProgramData\ExampleData
SymLinks=$Lib$\Settings|%APPDATA%\ExampleSettings
```

With two fields, X-Launcher forces `RunWait=true` and removes the link after the application closes. It deletes the link itself only, never the target. Add `|*` to keep a link permanently:

```ini
Junctions=C:\ExistingData|C:\ProgramData\ExampleData|*
```

Do not add a trailing pipe when `*` is not used. Existing normal files and directories are never overwritten. An existing link is accepted only when it resolves to the requested source; because X-Launcher did not create that link, it will not remove it. Directory junction targets must be local paths. Symbolic links may require Windows Developer Mode or starting X-Launcher with **Run as administrator**. The launcher itself does not request elevation automatically.

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
JavaPath=D:\PortableApps\CommonFiles\Java64
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
Diagnostics\<LauncherName>_Configuration_Probe_<timestamp>_<pid>.log
```

The interactive run opens the report when complete.

## Application Trace

Trace is not read-only. It launches the actual configured application and runs the configured file, registry, environment, and other operations. Each run creates:

```text
Diagnostics\<AppName>\<timestamp_millisecond_pid>\
    Application_Trace_Summary.txt
    Application_Portability_Report.txt
    X-Launcher_Settings.log
    X-Launcher_Debug.dbg
    Application_Trace.pml       (only when native capture is saved)
```

With a saved native Process Monitor capture, `Application_Portability_Report.txt`
is the single readable review file. It attributes successful write-like file,
directory, and registry events to the application or X-Launcher process trees,
collapses repeated low-level events by target, and separates application targets
into `CONTAINED`, `MANAGED`, and `UNMANAGED` groups. `MANAGED` means the target
matches a resolved path or portable REG root in the current INI. `UNMANAGED`
means it is outside `Root` with no such current rule and should be reviewed; it
is not automatic proof of a portability defect. The report also includes relevant
failed write attempts, process/command-line evidence, after-exit file presence,
limitations, and privacy guidance.

If native capture or XML export is unavailable, X-Launcher still creates the
portability report with a clear `NOT AVAILABLE` reason. The native PML remains
the detailed source evidence. ProcMon XML's fixed process list is used to map
event `ProcessIndex` values to PID, parent PID, process name and command line,
independent of visible columns. If the optional Detail field is not exported,
ambiguous `CreateFile` events are excluded so ordinary reads are not reported as
writes. Intermediate XML and canonical CSV files are removed after successful
analysis and retained only when their stage fails for troubleshooting.

`ProcMonPath` may contain the Process Monitor executable or its folder. Absolute paths and paths relative to `Root` are accepted. If blank, X-Launcher tries `$Lib$\Tools\ProcessMonitor\Procmon64.exe`. Supported executable names are `Procmon64.exe`, `Procmon.exe`, and `Procmon64a.exe`, selected for the operating-system architecture.

X-Launcher does not download Process Monitor, silently accept its licence, or take over an existing Process Monitor session. Starting, stopping, and exporting native capture can display UAC prompts, and Process Monitor can show its first-run licence prompt. If Process Monitor is unavailable, Trace offers an X-Launcher-only report or cancellation.

Trace automatically creates a temporary write-focused Process Monitor configuration for each session. It captures Process Monitor's `Write`, `Write Metadata`, and `Process` categories, then the report attributes the application and X-Launcher process trees and compares their targets with the portable Root and current INI. Keeping all capture inclusions on the same ProcMon field also retains writes made by application children located outside Root. Process Monitor's `Drop Filtered Events` option is enabled so unrelated reads and general system noise do not fill the PML. Duplicate low-value timestamp, allocation, flush, security metadata and Windows BAM bookkeeping events are dropped while create, content-write, rename, delete and registry data operations remain available. Users do not need to create ProcMon filters or add another INI setting. The temporary configuration is removed after successful analysis and retained with the XML/CSV only when a stage fails.

After the application closes, a tray notification identifies the current finishing phase: Process Monitor export, event conversion, or target/INI classification. The debug and settings logs record the duration of each phase. During conversion, fixed XML fields use direct extraction and non-reportable Process/metadata events are rejected before their remaining fields are decoded. Canonical CSV rows use a fast parser, the initial process-relation block is read without a redundant full-file scan, and repeated targets are collapsed through an indexed lookup.

`DirRemove=Path` recursively removes the directory and all its contents; it needs no option. `DirRemove=Path|e` changes the operation to empty-directory-only cleanup and recursively removes only directories that are empty. The `|o` overwrite flag belongs to move and copy operations and is invalid for `DirRemove`.

`DirRemove` cleanup is idempotent. If its resolved target is already absent, ordinary and empty-only (`|e`) removal return success. Configuration Probe reports the absent operation as `NOT USED`, so it remains visible in the complete report without appearing in the FAIL/WARN summary. Invalid paths, non-directory targets and genuine removal failures remain failures.

Process Monitor is executed for three different jobs: start capture, stop capture, and reopen the saved PML for XML export. These are not three separate captures. Windows can request elevation for each control execution.

The optional PML safeguards default to `ProcMonMaxMB=512` and `ProcMonReserveMB=1024`. Accepted values are 64-102400 MB and 256-102400 MB respectively. Capture is stopped and preserved as partial evidence if a limit is reached.

### The basic process is:

1. Create a minimal INI that can launch the application.
2. Set TestRun=Trace and configure ProcMonPath.
3. Launch the application through X-Launcher.
4. Use the application normally:
   - Change settings
   - Open its main features
   - Install plugins if relevant
   - Then close it normally
5. X-Launcher saves:
   - Application_Trace_Summary.txt
   - Application_Portability_Report.txt
   - Application_Trace.pml
6. Open `Application_Portability_Report.txt` and review the `UNMANAGED` application file, folder and registry targets. Use the PML in Process Monitor only when the detailed source events need closer inspection.
7. Add the appropriate environment settings, file operations and registry handling to the application’s X-Launcher INI.
8. Run Trace again to check whether those changes are now being handled.
9. Repeat until no unacceptable residue remains.

The distinction is:

The text summary explains what X-Launcher did.
The portability report gives a readable classification of captured application and X-Launcher write targets.
The PML contains the detailed source application activity for closer inspection when required.

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

X-Launcher-only Trace evidence can report launcher operations and launch/process results, but it cannot observe all activity performed later by an application. Even a native Process Monitor capture cannot automatically decide whether every change is persistent user data or intended behavior. Registry presence is not inferred beyond the last captured action. Attribution can be incomplete for services, brokers, elevated processes, and short-lived child processes. Writes outside `Root` are warnings for review, not automatic proof of failure.

Reports, `.log`, `.dbg`, and `.pml` files can contain usernames, paths, command lines, document names, registry data, and other private information. Review them before sharing and delete diagnostic output when it is no longer needed.

---

## Testing

The available user-facing modes are:

- TestRun=Probe
  - Examines that application’s real INI.
  - Checks sections, settings, paths, operations, Java configuration and safety problems.
  - Does not launch the application or perform its operations.
  - This answers: “Is my INI configured sensibly?”
- TestRun=Trace
  - Runs the real application using its real INI.
  - Records what X-Launcher did, whether operations succeeded, process results and cleanup.
  - Optionally uses Process Monitor to create a readable portability report of wider application activity.
  - This answers: “Did my INI and X-Launcher work during a real launch?”
- TestRun=Full
  - Tests X-Launcher’s own internal functions in an isolated workspace.
  - Ignores the configured application and its operations.
  - This answers: “Is this compiled X-Launcher functioning correctly?”
- TestRun=false
  - Normal application launch.
  - Users restore this after testing.

Debug=true additionally produces detailed .dbg and .log files during normal launches.

| Component | Intended user | Purpose |
|---|---|---|
| Test_Suite | Developer/maintainer | Proves the audit repairs haven’t broken anything. Its 56 tests validate X-Launcher code. |
| Debug_Feature_Test_Kit | Developer/maintainer | Proves the newly built diagnostic features themselves work correctly. It is not for testing normal applications. |
| Built-in TestRun modes | Ordinary X-Launcher user | Tests X-Launcher itself or a user’s real application INI. |

