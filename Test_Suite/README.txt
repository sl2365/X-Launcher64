Test_Suite

Run BUILD_TEST.bat from the X-Launcher project root.

Current tests:
- Exit Handler
- Launch Failure Detection
- Ignore Unrelated Same-Name EXE
- Preserve Multiple Instances
- Preserve RunWait False
- RunAfter Requires Waiting
- FileMove Wildcard No-Match Semantics
- RunAfter Stop-On-Failure Policy
- Registry Command Exit Code
- Registry Backup Failure Safety
- Registry Restore Failure Safety
- Registry 32-bit View

Test 08 requires 64-bit Windows. It uses the redirected disposable key:
HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05

It creates different host values in the 32-bit and 64-bit registry views.
With RegView=32, X-Launcher must apply the portable data only to the 32-bit
view and must restore that view afterward without changing the 64-bit view.

All test registry data is deleted afterward.

Issue 05 v2:
- Corrects the Test 08 payload helper.
- The helper no longer relies on delayed-expansion variables or a piped SET
  command, either of which could make the active-view result fail falsely.
- No X-Launcher source change is required before rerunning this baseline.

Issue 05 v3:
- Test 08 checks RegView=32.
- Test 08B checks RegView=64.
- Test 08C omits RegView completely and verifies backward-compatible Native
  behavior for the current x64 launcher.
- All three tests use distinct disposable redirected HKCU keys.

Issue 06:
- Test 09 simulates an interrupted registry transaction.
- It starts X-Launcher, waits until disposable portable registry data is active,
  then force-terminates only that test X-Launcher process.
- The test target process is also terminated so a second launcher run can begin.
- The original backup must survive the interruption.
- Before the second run, the portable .reg data is changed.
- A repaired X-Launcher must recover the original HOST data before creating any
  new backup; after the second run the host value must again be HOST.
- The test modifies only HKCU\Software\XLauncher_Test and Test_Suite\Working.
- PowerShell is used internally only to obtain the PID of the test launcher so
  the harness does not kill unrelated X-Launcher processes.

Issue 06 v2:
- Corrects the first interrupted-launch setup in Test 09.
- The test now copies X-Launcher_x64.exe to the unique name
  Issue06_Launcher.exe in the Test_Suite root.
- It starts that copy normally and force-closes it by its unique process name.
- This avoids PowerShell Start-Process argument quoting and avoids killing any
  unrelated X-Launcher process.
- The target is also uniquely named.
- No X-Launcher source change is required before rerunning this baseline.

Issue 06 v3:
- Corrects Test 09 target argument handling.
- The INI now leaves Parameters blank.
- ping.exe arguments are passed as separate X-Launcher command-line arguments.
- This keeps the first target alive long enough to establish and observe the
  interrupted registry transaction.
- The second run uses the same config with short command-line arguments.
- No X-Launcher source change is required before rerunning this baseline.

Issue 27:
- Test 10 checks protected-registry failure handling without using a real
  protected system/application key.
- It creates only HKCU\Software\XLauncher_Test\Issue27.
- A temporary explicit DENY rule blocks SetValue/CreateSubKey/Delete for the
  current user on that disposable key, while read/change-permissions access is
  retained so the test can verify and remove the rule afterward.
- The test first proves that a write really is denied.
- X-Launcher must preserve the original HOST value, must not apply Portable,
  and must NOT launch the application when the registry transaction cannot be
  completed safely.
- The temporary DENY rule and registry key are removed after the test.
- No X-Launcher source change is required before this baseline run.

Issue 05 compatibility extension - RegView=Auto:
- Test 11A copies the Windows 32-bit ping.exe from SysWOW64 and verifies that
  RegView=Auto selects the 32-bit redirected registry view.
- Test 11B copies the Windows 64-bit ping.exe from System32 and verifies that
  RegView=Auto selects the 64-bit redirected registry view.
- Test 11C uses a .bat target, whose PE bitness cannot be detected, and verifies
  that RegView=Auto falls back to the launcher's Native registry view.
- Detection is intended to be performed from the target each launch; no detected
  architecture is written back to the application INI.
- Existing INIs with no RegView setting remain covered by Test 08C and must keep
  the existing Native behavior.
- No X-Launcher source change is required before this baseline run.

Issue 24:
- Test 12 checks one .reg file containing two independent registry roots.
- Both roots start with distinct HOST values.
- During the portable run, both roots must contain their PORTABLE values.
- After X-Launcher closes, BOTH roots must be restored to their original HOST
  values.
- The current defect is expected to restore only the first root because the
  existing backup/load/restore logic treats only the first .reg section as the
  transaction root even though the entire .reg file is imported.
- Test data is restricted to HKCU\Software\XLauncher_Test.
- No X-Launcher source change is required before this baseline run.

Issue 24 Test 12 strengthened:
- The payload creates one new runtime value under each portable registry root.
- After X-Launcher closes, both runtime-only values must be absent from the host
  registry, proving both portable roots were removed before host restoration.
- Portable.reg must contain the runtime values from BOTH roots, proving that
  multi-root portable state is saved back rather than silently losing the
  second root.

Issue 24 Test 12 v3 correction:
- The prior save-back check used FINDSTR against REG.EXE's Unicode export file.
- That produced a false FAIL even though inspection proved both roots and both
  runtime values were present.
- Save-back verification now reads the .reg file with PowerShell Get-Content,
  which handles the exported Unicode encoding correctly.
- This is a test-harness correction only; no X-Launcher source change is needed.

Issue 26:
- Test 13 creates two registry files in one Regedit transaction.
- While the target is still running, it verifies that transaction.ini exists.
- The transaction manifest must record the actual backup files in transaction
  order as:
      [Backups]
      Backup1=backup-11.reg
      Backup2=backup-12.reg
- This makes restore/recovery order explicit instead of depending on filesystem
  directory enumeration.
- The test also verifies that normal host restoration still succeeds.
- Test data is restricted to HKCU\Software\XLauncher_Test.
- No X-Launcher source change is required before this baseline run.

Issue 25:
- Test 14 deliberately creates the ambiguous legacy backup-name collision:
      file group 1, registry file 11 -> backup-111.reg
      file group 11, registry file 1 -> backup-111.reg
- There are 21 registry inputs in one transaction.
- While the transaction is active, the test reads transaction.ini and requires
  every recorded backup filename to be unique.
- After normal cleanup, it verifies the host key whose backup would be
  overwritten by the collision, the later colliding host key, and a
  non-colliding sample host key.
- Test data is restricted to HKCU\Software\XLauncher_Test.
- No X-Launcher source change is required before this baseline run.

Issue 25 suite update:
- Test 13 no longer requires the old backup-11.reg / backup-12.reg naming.
- It now verifies the semantic requirement: Backup1 points to the backup
  containing HOST_A and Backup2 points to the backup containing HOST_B.
- This keeps Issue 26's restore-order regression valid while allowing Issue 25
  to replace the collision-prone filename format.

Issue 25 v3 regression-suite correction:
- Test 06 now blocks both the historical backup-11.reg name and the current
  backup-1-1.reg name, and requires launcher exit code 6 as well as host
  preservation. This prevents a false PASS when the intended backup failure
  was not actually induced.
- Test 07 corrupts/checks the current first-backup filename backup-1-1.reg.
- Test 09 no longer assumes a particular backup filename; it requires the
  transaction manifest plus at least one surviving .reg backup after the
  forced crash.
- These are test-harness updates only. No X-Launcher source change is required.

Issue 23:
- Test 15 exercises the documented [WriteToReg=Path\File] feature.
- WriteToReg must create a valid .reg file containing:
    a named REG_SZ value under the main key;
    a named REG_SZ value under a child subkey.
- The same generated file is then consumed by X-Launcher's RunBefore=Regedit
  path, so the payload must see both registry values.
- After launcher cleanup, the disposable host key must be absent.
- The generated .reg file is then imported directly with REG.EXE to confirm it
  is valid registry syntax independently of the payload check.
- The file itself must contain proper .reg named-string syntax:
      "RootValue"="ROOT_DATA"
      "ChildValue"="CHILD_DATA"
  rather than INI-style RootValue=ROOT_DATA.
- Test data is restricted to HKCU\Software\XLauncher_Test.
- No X-Launcher source change is required before this baseline run.

Issue 8:
- Test 16 exercises [Functions] DirMove in non-overwrite mode.
- Source and destination both contain Conflict.txt with different data.
- The destination collision intentionally prevents the source Conflict.txt from
  moving.
- A second source file, Movable.txt, has no collision and should move normally.
- Correct safety behavior:
    * destination Conflict.txt remains unchanged;
    * Movable.txt moves to the destination;
    * the unmoved source Conflict.txt remains intact in Source.
- The current defect is expected to move Movable.txt, fail to move Conflict.txt,
  then recursively delete Source and destroy the unmoved Conflict.txt.
- All destructive filesystem operations are restricted to Working\Test16.
- No X-Launcher source change is required before this baseline run.

Issue 18:
- Test 17 is a narrowly scoped external helper probe because X-Launcher's
  current production callers do not expose _DirCreate()'s @error status.
- The probe remains in Test_Suite and is never compiled into X-Launcher.
- RUN_TEST.bat temporarily copies the probe beside the project source so it can
  include the current x-udf.au3 directly, runs it with the same AutoIt
  v3.3.18.0 x64 interpreter used by the project, then deletes the temporary
  probe file.
- Scenario A verifies that a successful single-directory create both creates
  the directory and leaves _DirCreate() with @error=0.
- Scenario B creates a file that blocks an early directory request, follows it
  with valid directory requests, and verifies that the earlier failure is not
  hidden by the later successes.
- All test filesystem data remains beneath Test_Suite\Working\Test17.
- No X-Launcher source change is required before this baseline run.

Issue 19:
- Test 18 is the same narrowly scoped external helper-probe approach used for
  Issue 18. It remains inside Test_Suite and is never compiled into X-Launcher.
- Scenario A creates one file, calls _FileDelete() for that single file, and
  verifies both that the file was deleted and that the helper reports success.
- Scenario B deliberately asks FileDelete to delete a directory first
  (which must fail), followed by a normal file in the same directory group
  (which should delete successfully). The helper must retain/report the earlier
  failure rather than letting the later success hide it.
- All filesystem activity is restricted to Test_Suite\Working\Test18.
- No X-Launcher source change is required before this baseline run.

Issue 20:
- Test 19 uses the same narrowly scoped external helper-probe approach as
  Issues 18 and 19. It stays inside Test_Suite and is never compiled into
  X-Launcher.
- Scenario A verifies that a normal single-file copy both copies the file and
  reports success.
- Scenario B requests two files from the same source directory:
      Missing.txt;Later.txt
  Missing.txt deliberately does not exist, so the first copy must fail.
  Later.txt exists and should still copy successfully.
- The helper must retain/report the earlier failure rather than allowing the
  later success to overwrite the overall result.
- All filesystem activity is restricted to Test_Suite\Working\Test19.
- No X-Launcher source change is required before this baseline run.

Issue 21:
- Test 20 returns to normal black-box testing through the compiled X-Launcher.
- Failure scenario:
    FirstRun=true and a required FirstRun FileCopy references a missing source.
    Correct behavior is to retain FirstRun=true and not launch the payload.
    The repaired launcher may display its existing FirstRun error dialog; the
    test waits long enough to inspect the state and then terminates only its
    disposable launcher copy.
- Success scenario:
    FirstRun=true and a valid DirCreate operation is requested.
    Correct behavior is to create the directory, set FirstRun=false, launch the
    payload, and exit normally.
- Each run uses disposable INI copies beneath Working so the permanent test
  templates are never changed by X-Launcher.
- All filesystem activity is restricted to Test_Suite\Working\Test20A/B.
- No X-Launcher source change is required before this baseline run.

Issue 12:
- Test 22 is a narrowly scoped external helper probe for _SplashScreen().
- It calls the current x-udf.au3 directly with an empty image, forcing the
  built-in x-splash.jpg fallback path.
- The supplied Temp parameter points to Working\Test22\IntendedTemp.
- A controlled global $tempdir points to Working\Test22\WrongTemp. This makes
  the current defect safe and prevents it from trying to write to a drive root.
- Correct behavior stores x-splash.jpg only in the supplied Temp directory.
- The probe remains in Test_Suite and is never compiled into X-Launcher.
- No X-Launcher source or INI change is required before this baseline run.

Issue 13:
- Test 23 is a normal black-box test through a disposable launcher copy.
- It configures an explicit existing splash image with a 5000 ms timeout.
- The payload writes a marker immediately when it starts.
- Correct behavior starts the payload within two seconds while the splash
  timeout is still active.
- The current defect blocks inside _SplashScreen() for the full timeout, so the
  payload marker is absent at the two-second check.
- The disposable launcher copy is terminated after the check so the expected
  baseline failure does not add five seconds to every suite run.
- No X-Launcher source or INI change is required before this baseline run.

Issue 14:
- Test 24 is a narrowly scoped external helper probe for _SplashScreen().
- It requests a unique splash title and a 421 by 257 pixel client area.
- The probe requires the unique title to identify the splash window, then uses
  WinGetClientSize() to verify the configured width and height independently.
- It also creates a disposable 181 by 117 BMP, verifies _ImageGetSize(), checks
  that blank dimensions use the image's natural size, and verifies that either
  omitted dimension is calculated without changing the aspect ratio.
- The probe closes the splash immediately after inspection and remains outside
  the compiled X-Launcher application.

Issue 15:
- Test 25 is a normal black-box test through the compiled X-Launcher.
- It temporarily sets the launcher process environment to LANG=it and uses a
  test INI with no explicit Lang entry.
- WriteLog=true exposes the final automatic language value in the disposable
  25_Automatic_Language.log file.
- Correct behavior records Lang=it, launches the payload, and exits normally.
- The current defect discards _SystemLanguage()'s return value, so the payload
  still runs but the generated log does not contain Lang=it.
- RUN_TEST.bat restores its previous LANG environment value after the launch.
- No X-Launcher source or INI change is required before this baseline run.

Issue 16:
- Test 26 is a narrowly scoped external source-contract probe because Issue 17
  separately covers the visible TrayTip duration behavior.
- It requires x-launcher.au3 to read the documented [TrayTip] Timeout key first.
- It also requires the historical trailing-space spelling to remain available
  only as a fallback for backward compatibility with existing INIs.
- The current source reads only the trailing-space spelling, so both contract
  checks are expected to fail before the repair.
- The probe remains in Test_Suite and is never compiled into X-Launcher.
- No X-Launcher source or INI change is required before this baseline run.

Issue 17:
- Test 27 is a narrowly scoped external source-contract probe.
- AutoIt TrayTip() accepts an approximate duration in seconds, while
  AdlibRegister() accepts its interval in milliseconds.
- Windows may clamp, ignore, or suppress balloon-tip timing, so visual elapsed
  time is not a stable automated assertion.
- The probe requires the configured milliseconds to be rounded up to seconds
  for TrayTip(), while the existing callback retains the original millisecond
  value so it can hide the tray icon at the configured time.
- The current source passes a hard-coded 3 to TrayTip(), so the conversion and
  converted-value checks are expected to fail before the repair.
- The probe remains in Test_Suite and is never compiled into X-Launcher.
- No X-Launcher source or INI change is required before this baseline run.

Issue 22:
- Test 28 is a narrowly scoped external behavioral probe for
  _StringRegExpReplace().
- It writes three identical matches, requests a Counter value of 2 through the
  existing delimiter|Counter flag syntax, and requires only the first two
  matches to be replaced.
- StringSplit() returns the Counter field as a string. The current IsInt()
  check rejects that parsed value, leaves the replacement count at 0, and
  therefore replaces all three matches instead of two.
- The probe operates only on a disposable file beneath Working\Test28 and
  remains outside the compiled X-Launcher application.
- No X-Launcher source or INI change is required before this baseline run.

Issue 28:
- Test 29 is a normal black-box test through the compiled X-Launcher.
- RUN_TEST.bat compiles a disposable argument-recording EXE beneath
  Working\Test29 and launches it with HideShellWindow=true.
- Its configured arguments contain a leading option and a literal ampersand.
- A direct EXE launch must deliver exactly two arguments: --mode and
  alpha&beta.
- The current hidden-window branch routes the complete EXE command through
  cmd.exe /c, so the unquoted ampersand is interpreted as a command separator
  instead of being delivered to the EXE.
- A second launch forwards one command-line argument containing both a leading
  option marker and a space: --label value.
- That single argument must remain one payload argument. The current source
  removes its quoting solely because it begins with -, splitting it into two.
- The helper executable and its output are disposable Test_Suite files.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 29:
- Test 30 is a narrowly scoped external behavioral probe for all five existing
  text-rewrite functions: _MozPrefs(), _StringReplace(),
  _StringRegExpReplace(), _WriteToFile(), and _WriteToPref().
- Each function receives its own disposable UTF-8 BOM fixture containing LF
  line endings, a non-ASCII character, and a trailing blank line.
- Each exact binary result must contain the requested text change while
  retaining the BOM, UTF-8 bytes, LF format, and trailing blank line.
- The current line-oriented rewrites use default FileOpen/FileWriteLine modes,
  normalize line endings, and discard trailing empty lines. The whole-string
  regular-expression rewrite can also lose its original encoding on output.
- All fixtures remain beneath Test_Suite\Working\Test30.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 30:
- Test 31 is a narrowly scoped external behavioral probe for _MozPrefs().
- Separate User and Global fixtures each contain a commented occurrence, a
  longer similarly named preference, the exact target, and an unrelated
  preference.
- Only the exact user_pref("name", ...) or pref("name", ...) target may be
  replaced. Comments and longer preference names must remain byte-for-byte
  unchanged.
- The fixtures retain the UTF-8 BOM, LF line endings, and trailing blank line,
  so the completed Issue 29 format-preservation repair remains covered.
- All fixtures remain beneath Test_Suite\Working\Test31.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 31:
- Test 32 is a narrowly scoped external behavioral probe for
  _ExpandMultiPath().
- It supplies one ordinary relative file and one wildcard relative file using
  the same Root-based path convention.
- The helper deliberately changes the process working directory before calling
  the function. Both entries must still resolve against Root and be returned as
  absolute paths.
- With OnlyIfExist enabled, both existing files must be retained regardless of
  the process working directory.
- All files remain beneath Test_Suite\Working\Test32.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 32:
- Test 33 is a string-only external behavioral probe for UNC/network path
  preservation. It never contacts a server or network share.
- _FullPath() must retain an existing \\server\share path unchanged.
- _NormalPath() must preserve the two leading UNC separators while collapsing
  redundant separators inside the path.
- A //server/share input must normalize to a valid backslash UNC path.
- _FileInfo() must return a parent path that still begins with \\server\share.
- The probe writes only its log beneath Test_Suite\Working\Test33.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 33:
- Test 34 is a local external behavioral probe for _FixDriveLetter().
- A valid C:\ path must still be rewritten to the configured X:\ drive.
- Drive-like text embedded inside a longer token, such as ABC:\NotAPath, must
  not be treated as a Windows drive path.
- A C:/ segment inside an https:// URL must remain unchanged.
- A non-drive Root is tested in a hidden child AutoIt interpreter with
  /ErrorStdOut. It must return safely without changing the file or overrunning
  the replacement array.
- The UNC value is used only as a string argument; no network access occurs.
- All files remain beneath Test_Suite\Working\Test34.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 34:
- Test 35 is a local external behavioral probe for _FixUserProfile().
- A valid direct child directory must still be renamed and its saved name
  updated.
- A blank saved name must preserve the profile root and its sentinel while
  recording the current directory name.
- A parent traversal name such as ..\TraversalVictim must not move a sibling
  directory into the profile.
- A nested name such as Nested\OldDesktop must not be accepted because the old
  value must be one simple child-directory name.
- Every profile, sibling, directory, configuration file, and sentinel is
  disposable and remains beneath Test_Suite\Working\Test35.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 34 v2 baseline correction:
- The original Test 35 helper used DirExists(), which is not an AutoIt
  function, so the interpreter stopped before Probe.log was created.
- All directory-existence checks now use FileExists(), which supports both
  files and directories in AutoIt.
- Test intent, fixtures, expected behavior, and X-Launcher source are
  unchanged.

Issue 35:
- Test 36 is a string-only external behavioral probe for _FullPath().
- A valid single-parent path must still normalize from C:\Base\Child to
  C:\Base\Target.
- An excessive parent traversal is run in a hidden child AutoIt interpreter
  with /ErrorStdOut so the current Exit(10) cannot terminate the test suite or
  display a runtime dialog.
- Correct behavior is an empty return value with nonzero @error, followed by
  continued child execution.
- No path is accessed or modified. Only the probe log and child markers are
  written beneath Test_Suite\Working\Test36.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 37:
- Test 37 is a source-level external probe for the optional Java download
  helper. It does not enable Java, start X-Launcher, or make a network request.
- The asynchronous loop must continue while completion status is false and stop
  when InetGetInfo(handle, 2) reports completion.
- A failed asynchronous start must be rejected, completed-transfer success must
  be checked with InetGetInfo(handle, 3), and the existing byte-size validation
  must remain present.
- The probe writes only Test_Suite\Working\Test37\Probe.log.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 38:
- Test 38 is a source-level external probe for fatal errors inside the optional
  Java transaction. It does not enable Java or execute installation operations.
- _Error_Msg() must restore the Java backup and return _CloseJG(4).
- Each of the four fatal _JavaGet() call sites must immediately return that
  result so execution cannot continue after restoration.
- The probe writes only Test_Suite\Working\Test38\Probe.log.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 38 v2 baseline correction:
- The original helper requested AutoIt's global captured-match array mode but
  supplied no capture group, so the four correct caller lines were counted as
  zero after the source repair.
- The two caller patterns now capture their complete match before counting.
- Test intent and X-Launcher source are unchanged.

Issue 38 v3 baseline correction:
- AutoIt's global regular-expression result mode still did not provide a
  dependable flat caller count in the v2 helper.
- Caller counting now uses two exact StringReplace() searches and @extended,
  which directly reports the number of replacements without changing the
  source text held in memory.
- Test intent and X-Launcher source are unchanged.

Issue 38 v4 baseline correction:
- The v4 helper removes caller-function extraction and all replacement or
  regular-expression counting.
- It searches the complete source directly: the fourth corrected caller must
  exist, a fifth must not exist, and the old fall-through caller must not exist.
- Test intent and X-Launcher source are unchanged.

Issue 39:
- Test 39 is a source-level external probe for the optional Java tray Exit
  callback. It does not enable Java or start an installation.
- A private cancellation state must be declared and set by _ExitJG().
- _JavaGet() must return through its normal close path when cancellation is
  signalled, and an active asynchronous download must stop cooperatively.
- Existing Java backup restoration and tray-close behavior must remain present.
- The probe writes only Test_Suite\Working\Test39\Probe.log.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 40:
- Test 40 is a source-level external probe for result handling across the
  optional Java helper and the launcher. It does not enable Java, start
  X-Launcher, or perform installation operations.
- _JavaCheck() must capture _JavaGet()'s result and propagate a nonzero result
  through @error. The launcher must capture that error immediately.
- Java=true is required: a failed or cancelled Java setup must stop before the
  application launches. Java=optional must retain its existing fallback, and
  the Java path assignment interface must remain unchanged.
- The probe writes only Test_Suite\Working\Test40\Probe.log.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 41:
- Test 41 is a source-level external probe for Java version selection. It does
  not enable Java, inspect installed Java, or run installation operations.
- The standard Misc.au3 version helper must be included and _VersionCompare()
  must compare the host and portable multipart version strings.
- The old direct >= comparison must be absent. A comparison result of zero must
  retain the existing behavior of preferring host Java.
- Issue 40 result propagation must remain present.
- The probe writes only Test_Suite\Working\Test41\Probe.log.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 42 Phase A:
- Test 42 is a source-level external probe for the new Java runtime policy. It
  does not download Java, alter Lib\Java, or run installation operations.
- JavaURL must be read from the application INI and passed explicitly into the
  Java transaction. The hidden legacy winPenPack URL must be absent.
- A valid portable Lib\Java runtime must take priority over system Java.
- If required Java is missing and JavaURL is empty, the launcher must show a
  brief message directing the user to JavaURL= or Lib\Java\setup, then retain
  the controlled required-Java exit.
- Existing Java=optional fallback behavior must remain present.
- The probe writes only Test_Suite\Working\Test42\Probe.log.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 42 Phase B:
- Test 43 checks the modern ZIP staging and complete Java transaction
  contract without downloading or installing a real Java distribution.
- Disposable runtime trees verify that bin, lib, conf, legal, and root files
  are all backed up and restored while Lib\Java\setup remains untouched.
- Direct and single-wrapper ZIP layouts must be recognized. Ambiguous archives
  must be rejected before the live portable runtime is backed up.
- ZIP packages and legacy EXE packages must both remain discoverable, and the
  existing legacy core.zip/unpack200 path must remain available.
- The probe writes only Test_Suite\Working\Test43\Probe.log and disposable
  content below that Test43 folder.
- No X-Launcher source or application INI change is required before this
  baseline run.

Issue 42 Phase C:
- Test 44 is the final external baseline for configurable Java downloads and
  vendor-neutral system Java discovery. It performs no network or registry
  writes and does not install Java.
- The default template must document an optional empty JavaURL= key, while old
  application INIs without that key must retain their empty-default behavior.
- JavaURL accepts direct HTTP or HTTPS package URLs only. Invalid required-Java
  URLs must stop safely with brief guidance, and downloaded packages must use a
  format-neutral local filename rather than assuming an EXE.
- The configured URL must be passed unchanged to the downloader.
- When no portable Java can be used, system fallback must recognize JAVA_HOME,
  PATH, and both legacy and modern JavaSoft registry locations in 32-bit and
  64-bit views. Portable Lib\Java remains the first choice.
- JAVA_HOME and PATH checks use disposable fake runtime trees. Environment
  values are restored immediately after the probe.
- The probe writes only Test_Suite\Working\Test44\Probe.log and disposable
  content below that Test44 folder.
- No X-Launcher source or application INI change is required before this
  baseline run.

Built-in Diagnostics Stage 3:
- Test 45 verifies optional TestRun parsing and safe routing.
- Two black-box launches prove that an old INI without TestRun and an explicit
  TestRun=false INI both launch their disposable payload normally.
- A source-level AutoIt probe verifies the UTF-8 template default, blank-value
  fallback, case-insensitive Probe/Trace/Full modes, invalid-value stop,
  command-line forms and override precedence, the four selection outcomes,
  cancellation exits, and the stop boundary before registry recovery or any
  configured application operation.
- Modal TestRun choices are not launched unattended, so the one-click suite
  cannot hang waiting for confirmation.
- All runtime files remain beneath Test_Suite\Working\Test45. The probe writes
  only Test_Suite\Working\Test45\Probe.log.

Built-in Diagnostics Stage 4A:
- Test 46 runs the first real Configuration Probe through copied launchers and
  disposable INIs beneath Test_Suite\Working\Test46.
- The valid case verifies a readable report with a zero-failure summary. The
  invalid case verifies excessive path traversal, a missing executable,
  invalid Boolean, RegView and TestRun values, corrected MultipleInstances
  validation, legacy-key precedence reporting, and an unknown section.
- The automated switch is accepted only with the direct read-only Probe mode.
  It suppresses confirmation and report opening so the permanent suite cannot
  hang. It cannot suppress confirmation for INI selection, the selection
  window, Application Trace, or Full X-Launcher Test.
- The test proves that Probe does not launch the configured payload, rewrite
  either INI, change a sentinel, or create the configured Temp, Cache or Home
  directories. The report is written only below each disposable launcher's
  Diagnostics folder.
- Stage 4B extends the same isolated test group with Environment, Functions,
  FirstRunOperations, RunBefore and RunAfter validation. Valid operation names,
  delimiter structures, required sources, RunFile targets, protected deletion
  targets and REG file headers/roots are checked without execution.
- The valid fixture deliberately configures file creation, copying, moving,
  deletion, directory removal, FixDriveLetter, RunFile, AddFonts and Regedit.
  Test 46 proves that every source and sentinel remains unchanged, no target or
  run marker appears, the REG file remains byte-identical, and the disposable
  HKCU host value is not replaced by the portable value.
- Windows-valid environment names containing parentheses or spaces must be
  accepted. A blank name or a name containing the reserved equals separator
  must state the exact reason it cannot be accepted. Unknown/misspelled
  operation names, missing delimiters, missing RunFile targets and missing REG
  files must still be reported.
- Stage 4C completes Probe validation for StringReplace,
  StringRegExpReplace, WriteToFile, WriteToIni, WriteToPref and WriteToReg.
  Wildcard matches are listed, regular expressions are compiled against an
  empty string, and all write targets and entry structures are checked without
  calling a modifying function.
- The same test now verifies Java=false/true/optional policy parsing, portable
  Java priority, ZIP and legacy EXE setup recognition, direct HTTP/HTTPS
  JavaURL validation, and read-only system Java fallback discovery.
- The valid fixture contains disposable rewrite targets, a fake portable Java
  runtime and a setup package. The invalid fixture contains malformed dynamic
  entries, an invalid JavaURL and a non-MZ legacy package. Byte comparisons and
  absence checks prove that Probe does not rewrite targets, generate REG/INI/
  preference files, download Java, stage an installation or alter Java files.
- Test 46 remains one grouped permanent regression. Stage 4C is the complete
  Configuration Probe checkpoint.
- Stage 4C v2 corrects only the valid-report heading assertion. Probe reports
  are intentionally UTF-8 with BOM, so the first heading is searched as a
  contained literal instead of an exact whole line. All remaining report
  assertions retain their exact or beginning-of-line matching.
- Stage 4D adds a regression requirement for the end of the Configuration
  Probe report. The summary must repeat every ordered FAIL and WARN detail
  from the report and must not repeat PASS or NOT USED details. The comparison
  uses the existing invalid fixture and does not execute configured operations.
- Stage 4E requires Configuration Probe reports to use the .log extension.
  Existing Probe assertions accept the previous .txt extension only for the
  pre-change failing baseline; the grouped result passes only when both valid
  and invalid Probe reports use .log.

Built-in Diagnostics Stage 5A:
- Test 47 is one grouped permanent regression for optional ProcMonPath
  resolution and Configuration Probe reporting.
- Direct absolute paths, Root-relative paths, $Lib$ variable expansion,
  environment-variable expansion, UNC preservation, configured folders and
  the blank $Lib$\Tools\ProcessMonitor\Procmon64.exe default are covered.
- Existing supported executable names are Procmon.exe, Procmon64.exe and
  Procmon64a.exe. A configured directory is searched only at its exact level,
  with the native architecture name preferred.
- A found tool is PASS, a missing or unsupported configured value is WARN, and
  a blank value with no default tool is NOT USED. ProcMon availability never
  makes Configuration Probe fail.
- Five copied launchers and disposable INIs run read-only Probe cases beneath
  Test_Suite\Working\Test47. The test verifies that no payload is launched and
  every fake Process Monitor fixture remains byte-identical.
- The resolver does not launch or download Process Monitor and does not accept
  its EULA. Application Trace control is intentionally outside Stage 5A.

Built-in Diagnostics Stage 5B:
- Test 48 is one grouped permanent regression for the X-Launcher-only
  Application Trace path. It does not run the interactive real Trace.
- The helper verifies the explicit real-run confirmation route, the missing
  Process Monitor choice, unique per-application session folders, internal
  debug/settings paths and suppression of diagnostic command-line switches
  from the configured payload.
- Stage 5B resolves and reports ProcMonPath but never starts or downloads
  Process Monitor, accepts its EULA, requests elevation or creates a PML file.
- Explicit Trace temporarily enables enhanced logging and waiting without
  changing the INI. It records the launcher PID, direct application PID, exit
  result and best-effort observed child-process details.
- Application_Trace_Summary.log separates X-Launcher-recorded file/directory,
  registry, process and error details; Root/outside-Root and residue headings;
  PASS/FAIL/WARN/SKIP/NOT USED totals; privacy guidance; limitations; and the
  complete ordered debug detail.
- The permanent helper creates synthetic report input and runs one disposable
  loopback command below Test_Suite\Working\Test48. The explicitly confirmed
  real application run is covered by the separate focused Stage 5B test kit.
- Stage 5B v2 completes the categorized file/directory summary with
  DirCreate, text-rewrite, write and font-operation results. The focused test
  accepts either existing cleanup-required waiting or Trace-required waiting;
  both retain the complete waited lifecycle.
- Stage 5B v3 retains a Windows process handle throughout the one-second Trace
  observation loop so the real application exit code remains available after
  process termination. This avoids AutoIt's already-exited 0xCCCCCCCC sentinel
  while preserving child-process observation and complete lifecycle waiting.
- Stage 5B v4 uses strict string comparison for the unavailable-exit-code state
  so a valid numeric exit code of zero cannot also generate a false warning.
  The permanent and focused tests now reject that contradictory result.
- Stage 5B v5 corrects the permanent Test 48 helper's AutoIt path literal for
  the Diagnostics folder. This is a regression-harness correction only;
  X-Launcher source and runtime behaviour are unchanged.
- Stage 5C starts an optional native Process Monitor backing-file capture when
  ProcMonPath resolves successfully, no ProcMon instance is already running,
  and the user completes any Windows elevation or Process Monitor licence
  prompts. X-Launcher never supplies /AcceptEula and never downloads ProcMon.
- Capture uses the verified /BackingFile, /Minimized and /Quiet switches, then
  /Terminate only after RunAfter, registry restoration, font removal and Temp
  cleanup. Application_Trace.pml is preserved beside the text Trace report.
- A pre-existing ProcMon instance is never controlled or terminated; Trace
  continues with X-Launcher-only logging and records a warning instead.
- Stage 5C preserves the native PML as detailed source evidence. Stage 8 adds
  automatic export, attribution and readable portability summarisation.
- Stage 5C v2 removes the premature two-second startup abort. Process Monitor
  now retains the full 60-second allowance while elevation or licence prompts
  are completed and while the native PML backing file is created.
- Stage 5C v3 explicitly requests Windows elevation for both Process Monitor
  capture startup and termination. Cancelling either elevation prompt remains
  a safe warning/fallback rather than automatic privilege bypass.
- Stage 5D adds bounded native capture storage safeguards. Optional
  ProcMonMaxMB and ProcMonReserveMB settings default to a 512 MB maximum PML
  and 1024 MB of preserved free space. Capture does not start unless the
  maximum plus reserve is available.
- While the application is running, Trace rechecks PML size and free space.
  Reaching either safeguard stops ProcMon, preserves the partial PML, allows
  the application and cleanup to finish, and reports PASS WITH WARNINGS with
  the exact partial-capture reason, size and duration.
- Trace-mode settings and reports record the configured limits, initial free
  space, final capture size, duration and complete/partial status. Normal
  launches and existing INIs remain unchanged.
- Stage 8 adds Test 48B, one grouped permanent regression for the readable
  Application_Portability_Report.log parser and classifier. It uses controlled
  synthetic Process Monitor XML and CSV rows and does not start Process Monitor.
- Test 48B verifies automatic per-session same-column Category filtering for
  Write, Write Metadata and Process, Drop Filtered Events, /LoadConfig and
  /SaveApplyFilter command construction, low-value metadata/BAM exclusions,
  direct fixed-field XML extraction, early non-reportable event rejection,
  fast quoted-CSV parsing and indexed repeated-target collapse,
  XML process-index/PID mapping, quoted CSV parsing,
  repeated-event collapse, application
  child attribution, unrelated-PID exclusion, contained paths, current-INI
  file and portable REG-root coverage, unmanaged file/registry review entries,
  X-Launcher separation, relevant failed writes, after-exit file presence,
  limitations and privacy guidance. Test 49 remains the final Full Test gate.
- Stage 8E1 adds Test 48C for built-in FileMove wildcard no-match semantics.
  With no matching wildcard source, normal Debug output must report SKIP and
  the read-only Configuration Probe must report NOT USED. The next configured
  RunAfter operation must still execute. A missing exact FileMove source must
  remain FAIL, so genuine configuration mistakes are not hidden. Test 49
  remains the final Full Test gate.
- Stage 8E2 adds Test 48D for the optional RunAfterStopOnFailure policy. The
  missing option must default false and preserve the historical continue-after-
  failure behavior. When true, a wildcard no-match SKIP must not stop the next
  operation, but a genuine operation failure must stop later configured
  RunAfter entries. Mandatory registry restoration and internal Temp cleanup
  must still complete. Probe and Debug output must explain the policy, and the
  application template must document its backward-compatible false default.
  Test 49 remains the final Full Test gate.
- Stage 8E3 adds Test 48E for the optional FixLocalAppData and FixTemp portable
  environment defaults. Both missing options must preserve the inherited
  process environment and create no portable directories. FixLocalAppData=true
  must create and assign $Lib$\AppData\Local without changing TEMP or TMP.
  FixTemp=true must create $Lib$\AppData\Local\Temp and assign both Windows
  variables. Explicit [Environment] entries must take priority, Probe must
  recognize and validate both options, Debug must report all assignments, and
  the template and README must distinguish application Temp redirection from
  X-Launcher's internal Temp cleanup. Test 49 remains the final Full Test gate.
  Debug checks search after X-Launcher's normal timestamp prefix.
- Stage 8E4 adds Test 48F for the combined FixAppData, FixLocalAppData,
  FixTemp and USERPROFILE configuration. The payload must receive the correct
  APPDATA, LOCALAPPDATA, TEMP and TMP paths; x-launcher.cfg must store the real
  AppData leaf name without control characters; the normal .log must retain the
  full portable APPDATA path rather than only its leaf name; and x-launcher.cfg
  must remain byte-identical over two launches. Test 49 remains the final Full
  Test gate.
- A real Trace creates a temporary category-based ProcMon configuration, drops
  unrelated read/network/profiling activity during capture, stops and preserves
  the filtered Process Monitor capture, exports the PML to
  XML, maps event ProcessIndex values through the fixed process list, converts
  it to canonical parser input, creates the single readable portability report,
  and removes the XML, canonical CSV and temporary PMC configuration after
  successful analysis. Failed-stage files are retained
  for troubleshooting. Starting, stopping and exporting Process Monitor can request
  Windows elevation; X-Launcher still never downloads it or accepts its EULA.
- Application targets are classified as CONTAINED inside Root, MANAGED when a
  resolved current INI path or REG root matches, and otherwise UNMANAGED for
  review. X-Launcher process-tree actions are separate. These classifications
  are evidence and guidance, not proof that an INI rule is semantically right.
- File-system and Debug regression coverage verifies that ordinary and
  empty-only DirRemove calls treat an already-absent target as an idempotent
  successful no-op. Ordinary removal of unprotected targets retains its
  historical behaviour; protected-base cleanup modes are covered by Test 54.
- The focused RUN_STAGE8A_PORTABILITY_REPORT_TEST.bat performs a native smoke
  with disposable file and HKCU registry targets below the kit's test folders
  and HKCU\Software\XLauncher_Test. It removes the disposable registry keys.
- Stage 6A begins the isolated built-in Full X-Launcher Test. It creates a
  unique workspace below the current user's Temp directory and uses only a
  dedicated HKCU\Software\X-Launcher\SelfTest\<session> registry branch.
- The compiled launcher invokes a private second-copy helper to verify exact
  argument quoting, working directory, inherited environment, waited process
  completion and controlled nonzero exit codes without external helper files.
- Full Test treats the selected INI as report context only. It does not launch
  the configured application or execute Functions, RunBefore or RunAfter.
  Successful isolated workspace and registry state are removed; a failed-test
  workspace is preserved for diagnosis and its location is reported.
- Stage 6A v2 uses arguments supported by the compiled AutoIt command-line
  parser, including a quoted value with repeated spaces. The focused checker
  now requires explicit [PASS] detail lines and cannot accept [FAIL] text with
  the same description.
- The Stage 6A no-INI checker reports its launcher exit, missing-file state,
  report creation, zero-failure summary and context-only path as five separate
  results. This removes the former opaque combined-condition false negative.
- Stage 6B extends Full Test process coverage inside the same isolated Temp
  workspace. It verifies that the real launcher run helper reports a missing
  executable as a launch failure, then starts two private helper copies and
  proves that they have distinct PIDs, overlap in time and both close normally.
- Stage 6B does not launch the configured application or operations, does not
  use Process Monitor and does not require elevation. Exact helper PIDs are
  written only to the diagnostic report for that disposable test session.
- Stage 6C exercises X-Launcher's directory and file create, copy, move and
  delete functions only beneath the unique Full Test Temp workspace. Every
  operation target is checked against that boundary before fixtures are made.
- File and directory copy/move tests verify exact nested content. Safety cases
  prove that a non-overwrite copy collision preserves both files, empty-only
  directory removal preserves non-empty data, and deletion leaves a separate
  workspace sentinel unchanged. Failed workspaces remain available as before.
- Stage 6D creates five byte-exact UTF-8 BOM fixtures beneath the Full Test
  workspace. Each uses LF line endings, a non-ASCII character and a trailing
  blank line, matching the permanent external text-format regression.
- StringReplace, StringRegExpReplace, WriteToFile, WriteToPref and MozPrefs
  each make a controlled text change. Their resulting files must retain the
  original BOM, UTF-8 bytes, LF convention and trailing blank line exactly.
- Stage 6E exercises writer semantics only beneath the same isolated Full Test
  workspace. Every INI, preference and REG output path must pass the workspace
  boundary check before its fixture directory or output file is created.
- WriteToIni must create a new value, update it and preserve an unrelated
  sentinel. WriteToPref must create a new file, update an existing preference,
  append a second preference and return no-change for an identical value.
- WriteToReg must generate the exact REGEDIT4 header, root/subkey sections and
  quoted REG_SZ entries. The generated REG file is inspected as text and is
  never imported; the corresponding dedicated self-test registry child must
  remain absent. Test 49 remains one top-level permanent regression test.
- The Stage 6E full-suite harness correction updates Test 48's source probe to
  inspect the complete command-forwarding block after the private Full Test
  helper made its filter multiline. Test 49 now extracts each reported INI
  context path before exact case-insensitive comparison because FINDSTR cannot
  reliably use these long complete paths as /x search patterns. Launcher source
  and runtime behaviour are unchanged by these test-only corrections.
- Stage 6F adds real 32-bit and 64-bit registry-view isolation beneath a unique
  disposable HKCU\Software\Classes\CLSID\X-Launcher-SelfTest-<session> branch.
  Microsoft documents this CLSID branch as redirected on modern 64-bit Windows;
  ordinary HKCU\Software is shared and cannot prove view separation.
- The Full Test imports distinct values into both views, exports each view for
  exact isolation checks, then removes and verifies both view-specific keys.
  The additional view root is written to the report so permanent and focused
  harnesses can independently confirm cleanup.
- Beneath the original dedicated HKCU self-test root, two protected host keys
  exercise portable installation, pending transaction metadata, distinct
  ordered backups, normal restore order and portable-state save-back. A second
  pending transaction is recovered directly to simulate the next-start crash
  recovery path without terminating the test process.
- Registry fixture, export and backup paths must all pass the isolated Temp
  workspace boundary. Full Test temporarily selects its own minimal INI so a
  configured external registry manager cannot run. The application INI remains
  context only, no administrator elevation is requested, and Test 49 remains
  one top-level permanent regression test.
- Stage 6G exercises environment-variable and X-Launcher-variable expansion
  using only values that resolve beneath the isolated Full Test Temp workspace.
  Raw percent and $Root$/$Lib$ tokens are written with automatic expansion
  temporarily disabled, then read with the launcher's normal expansion options.
- FullPath covers relative, absolute and valid parent resolution against a
  supplied isolated root. FullPathPlus covers literal, forward-slash and quoted
  output modes. MultiPath proves that ordinary and wildcard entries both use
  Root rather than the current working directory.
- SetEnv and SetPath assign process-local values only. A blank environment name
  must fail, while multi-entry PATH resolution must be exact. The original PATH,
  test variables, working directory, Root, Lib and automatic expansion options
  are restored before Full Test continues. Test 49 remains one top-level test.
- Stage 6H adds one built-in Path Safety group for the previously repaired UNC,
  traversal, drive-letter, user-profile and Temp cleanup contracts. All mutable
  fixtures are created beneath the unique Full Test Temp workspace.
- UNC checks are string-only and do not contact a network share. FullPath must
  preserve a direct UNC value, while NormalPath and FileInfo must retain its
  prefix and parent. A valid parent path must resolve, while excessive parent
  traversal must return a nonfatal error so Full Test can continue.
- FixDriveLetter must rewrite only a genuine absolute drive path. Embedded
  drive-like text, URL segments and a file supplied with a non-drive base must
  remain unchanged. FixUserProfile must rename one valid direct child, preserve
  a profile whose old child is blank, and reject traversal or nested old-source
  names without moving their sentinels.
- Temp cleanup first receives an isolated Temp equal to its isolated Root and
  must refuse the recursive deletion. It then receives only a disposable child
  and must remove that child while preserving the Root sentinel. Root, Temp,
  Home and Backup are restored before Full Test continues. Test 49 remains one
  top-level permanent regression test.
- Stage 6I adds one built-in Splash Tray group. The fallback image is extracted
  only beneath the unique Full Test Temp workspace; no configured application
  image or folder is used. Splash creation must return before its five-second
  display timeout, proving that it does not delay launcher startup.
- The runtime checks identify the splash by a unique title and verify its exact
  configured 421 by 257 client area. A second isolated splash verifies that
  blank dimensions use the embedded image's natural 307 by 213 size. Both
  windows and their callbacks are explicitly closed before Full Test continues.
- TrayTip is activated with a 2500 millisecond duration, must return without
  blocking, and is immediately closed. Permanent external Tests 26 and 27
  continue to enforce documented Timeout-key precedence, legacy trailing-space
  compatibility, seconds conversion for TrayTip and milliseconds for its
  callback. Test 49 remains one top-level permanent regression test.
- Stage 6J adds optional JavaPath selection while preserving Java as the
  false/true/optional policy and JavaURL as the HTTP/HTTPS download fallback.
  Existing INIs without JavaPath remain compatible.
- JavaPath accepts an existing runtime root, bin folder, java.exe or javaw.exe.
  Absolute paths are accepted and relative paths, with or without an explicit
  .\ prefix, resolve from Root. Both java.exe and javaw.exe must be present.
  JavaPortableLauncher.exe is not treated as a Java runtime.
- A valid JavaPath is selected read-only before bundled Lib\Java, system Java,
  setup packages or JavaURL. It bypasses JavaGet and leaves the external
  runtime byte-identical. An invalid path is reported and the established
  fallback search continues. Java=false retains but ignores the configured
  path so it can be re-enabled without editing the value.
- The Java Path built-in group uses only fake runtimes beneath the unique Full
  Test Temp workspace. It checks absolute and relative paths, executable and
  bin normalization, incomplete-runtime rejection, priority, JavaURL bypass,
  Configuration Probe reporting, disabled behavior, read-only access and full
  restoration of Root, Lib, JAVA_HOME and PATH.
- Permanent Test 44 now covers the same public JavaPath selection contract in
  its disposable helper fixtures. Test 49 remains one top-level test and gates
  all eleven Java Path report assertions. The focused Stage 6J runner also
  rechecks the Stage 6F through 6I completion sentinels.
- Stage 6K adds one built-in Java Transaction group for the remaining safe
  package, staging, backup, cancellation and rollback contracts. Every file is
  synthetic and remains beneath the unique Full Test Temp workspace.
- JavaURL validation is string-only and accepts HTTP/HTTPS while rejecting
  FTP, file and blank values without network access. Disposable ZIP and MZ
  package headers are recognized without extraction or execution. Direct and
  single-wrapper staged runtime trees are accepted, while incomplete and
  ambiguous trees are rejected.
- A deliberately missing isolated extractor proves that failed package
  preparation removes staging before the live fake runtime is touched. Backup
  paths are restricted to one direct child of that runtime. Complete release,
  bin, lib, conf, legal and jmods content is backed up while setup and staging
  data remain outside the backup.
- The prepared-install check copies a complete replacement runtime. A forced
  cancellation must stop before destination mutation. Rollback then removes
  partial/new content, restores the complete old runtime, preserves its setup
  package, removes the transaction backup and restores the process working
  directory and cancellation state.
- Stage 6K performs no download, Java process launch or access to an installed
  Java runtime. Test 49 remains one top-level permanent regression test and
  gates all fourteen Java Transaction report assertions. Its focused runner
  also rechecks the Stage 6F through 6J completion sentinels.
- Stage 6L adds one isolated Debug Reporting group. Debug=false must create no
  result output. With Debug enabled, controlled calls verify PASS, FAIL, SKIP
  and WARN classification without executing a configured application target.
- The group proves that a legitimate text no-change is SKIP, a zero return is
  not blindly treated as PASS, and unknown operations remain compatible while
  receiving WARN. Waited launch success and non-waiting launch failure are
  distinguished without starting either fixture executable.
- Registry recovery, environment and Temp cleanup result records are checked
  for their documented classifications. A private debug session must emit
  exact boundaries, counters and summary totals. The debug file is confined to
  the unique Full Test Temp workspace and all Debug globals, counters, session
  flags and the process-local test environment variable are restored.
- Test 49 remains one top-level permanent regression test and gates all
  fourteen Debug Reporting assertions. The focused Stage 6L runner also
  rechecks the Stage 6F through 6K completion sentinels.
- Stage 6M adds the final built-in Full Test capability group: Configuration
  Probe parser cross-checks. It creates controlled valid and invalid INIs plus
  operation, dynamic-section, REG and fake Java fixtures only beneath the
  unique Full Test Temp workspace.
- The group calls the same Probe validators used by Configuration Probe. It
  checks fixed and dynamic sections, known and compatibility keys, Boolean,
  RegView, TestRun and integer options, resolved and UNC paths, environment
  entries, operation arguments, dynamic delimiters and selectors, JavaPath,
  JavaURL, setup-package headers and protected cleanup targets.
- RegView and TestRun validation are shared pure helpers so public Probe and
  Full Test cannot drift into different parser rules. The parser checks do not
  launch the configured application, create a separate Probe report, apply an
  environment setting, execute an operation, import REG data, run Java,
  inspect an installed Java fallback, install a package or access the network.
- Before-and-after comparisons prove that both INIs, all input targets, fake
  Java files, directories and the dedicated registry sentinel remain
  unchanged. Root, Temp, Lib, RunWait, DeleteTemp, working directory and INI
  expansion options are restored before Full Test cleanup.
- Test 49 remains one top-level permanent regression test and gates all
  eighteen Probe Parser assertions. Permanent Test 46 remains the public
  black-box Configuration Probe read-only contract. The focused Stage 6M
  runner also rechecks the Stage 6F through 6L completion sentinels.

Lower-priority cleanup and compatibility resolution:
- Test 50 verifies the corrected MultipleInstances option, confirms that the
  former misspelling is no longer accepted, and checks safe defaulting when the
  corrected value is blank or invalid.
- Test 51 verifies that both font-change broadcasts use SendMessageTimeoutW
  with pointer-sized LRESULT, WPARAM, LPARAM and DWORD_PTR-compatible types.
- Existing test INIs now use the corrected MultipleInstances spelling.
- Test 52A verifies temporary junction creation, forced RunWait, writes through
  the junction, and automatic removal of the junction without deleting its target.
- Test 52B verifies the persistent `|*` junction flag and confirms that manual
  test cleanup removes only the junction while preserving its target.
- Test 53A and Test 53B perform the equivalent temporary-file and
  persistent-directory checks for symbolic links. On a machine without Developer Mode or an
  elevated launcher, Windows error 1314 is accepted as an explicit privilege
  limitation rather than being mistaken for a functional success.
- Together with the expanded Test 24 splash checks, the suite now contains 67
  permanent regression tests.
- Test 46 now also verifies the original DirRemove contract: no flag means
  recursive removal of populated directories, |e means empty-directory-only
  cleanup, and |o is rejected with guidance that explains both valid forms.
- Test 46 classifies already-absent DirRemove targets as NOT USED rather than
  FAIL in Functions, FirstRunOperations and RunAfter. The complete Probe report
  retains the information while the FAIL/WARN attention summary omits it.
  Missing copy and move sources remain failures.
- Test 54 verifies protected Lib cleanup in both Configuration Probe and normal
  runtime operation. DirRemove=$Lib$ remains blocked, DirRemove=$Lib$|e removes
  only empty descendants while preserving Lib, a trailing separator removes
  contents while preserving Lib, and the combined trailing-separator |e form
  preserves non-empty content. Bin, Root, launcher and system paths remain
  protected from direct or contents-only recursive deletion.
- Test 46 now verifies that Configuration Probe accepts PROGRAMFILES(x86) and
  a custom name containing a space. Environment-name validation follows the
  Windows rule instead of a programming-language identifier rule: parentheses,
  spaces, leading digits and custom names are valid; the equals sign is the
  reserved separator. Probe does not guess whether an application reads a
  valid custom name. Test 48F also proves that PROGRAMFILES(x86) is assigned by
  normal X-Launcher execution, reaches the payload and is recorded by Debug.
- The v2.0.0.338 test-harness correction updates the permanent Test 49 and
  focused Stage 6M searches to the new environment result descriptions. The
  built-in Full Test already passed with zero failures; only the external
  sentence-matching count was stale. No launcher source or rebuild is required
  before rerunning Test_Suite\RUN_TEST.bat.

Issue 21 v2 baseline correction:
- The FirstRun=true/false checks no longer require one exact literal INI line.
- PowerShell now accepts harmless whitespace around the key and equals sign.
- This is a test-harness correction only. X-Launcher source is unchanged.

Issue 36:
- Test 21 is a normal black-box test through the compiled X-Launcher.
- It creates a disposable Root folder beneath Test_Suite\Working\Test21 and
  deliberately configures:
      Root=.\Working\Test21\ProtectedRoot
      Temp=.
      DeleteTemp=true
- Because Temp resolves to the same canonical path as Root, recursive Temp
  cleanup must refuse to delete it.
- The payload runs first and writes PayloadRan.txt. A separate Sentinel.txt is
  placed in Root before launch.
- Correct behavior:
    * payload runs normally;
    * Root still exists after launcher cleanup;
    * Sentinel.txt is still present and unchanged.
- The current defect is expected to recursively remove Root after the payload
  exits.
- No real project, user, Windows, or system folders are targeted. All
  destructive activity is restricted to Test_Suite\Working\Test21.
- No X-Launcher source change is required before this baseline run.

Issue 36 v2 baseline correction:
- PayloadRan.txt is now written to Working\Test21, one level outside
  ProtectedRoot.
- The original test wrote the marker inside ProtectedRoot, so the defect erased
  the evidence that the payload had run when it recursively deleted Root.
- Root and Sentinel checks are unchanged.
- This is a test-harness correction only. X-Launcher source is unchanged.
