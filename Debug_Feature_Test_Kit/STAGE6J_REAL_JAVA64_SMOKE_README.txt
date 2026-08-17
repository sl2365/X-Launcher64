X-LAUNCHER STAGE 6J REAL JAVA64 SMOKE TEST
==========================================

Purpose
-------
This is the final real-runtime acceptance check for the optional JavaPath
feature. It uses the installed PortableApps Java64 runtime at:

D:\SyMenu\ProgramFiles\PA.c\PortableApps\CommonFiles\Java64

It tests both:

1. JavaPath=<Java64 runtime root>
2. JavaPath=<Java64\bin\javaw.exe>

In both cases X-Launcher resolves $Java$\bin\java.exe and runs only:

java.exe -version

Safety
------
- No real application INI is opened or changed.
- No Java package is downloaded.
- No bundled Lib\Java runtime is installed or updated.
- The installed Java64 tree is read only.
- A complete recursive manifest verifies every runtime file and directory
  before and after the two launches, including file SHA-256 hashes, sizes and
  last-write metadata.
- All X-Launcher files and logs are kept in an isolated test folder beneath
  Debug_Feature_Test_Kit.

How to run
----------
1. Extract the ZIP into the X-Launcher source folder and allow Windows to merge
   the Debug_Feature_Test_Kit folder.
2. Open Debug_Feature_Test_Kit.
3. Double-click RUN_STAGE6J_REAL_JAVA64_SMOKE.bat. The batch file starts the
   corrected PowerShell-controlled test runner automatically.
4. Wait while the before and after manifests are created.
5. Upload only Stage6J_Real_Java64_Smoke_Results.txt.

Expected result
---------------
Passed: 23
Failed: 0
Overall: PASS

The corrected runner reports PASS only when all 23 checks were actually
recorded. A zero-check result is always reported as FAIL.

Windows PowerShell waits on X-Launcher using its process object, so the exit
code is collected reliably even though X-Launcher is a GUI-subsystem EXE.

If the Java64 installation is moved later, edit only the JAVA_ROOT= line near
the top of RUN_STAGE6J_REAL_JAVA64_SMOKE.bat before running it again.
