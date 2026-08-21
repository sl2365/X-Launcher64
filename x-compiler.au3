;   winPenPack X-Launcher

#Region

;** AUT2EXE settings
#AutoIt3Wrapper_UseUpx=N					 	    ; (Y/N) Compress output program. Default=Y
#AutoIt3Wrapper_UseX64=Y							; (Y/N) Compress output program. Default=Y
#AutoIt3Wrapper_Outfile_x64=X-Launcher_x64.exe		; Target exe/a3x filename.
#AutoIt3Wrapper_Icon=graphics\x-icon.ico			;Filename of the Ico file to use
#AutoIt3Wrapper_Compression=4						;Compression parameter 0-4  0=Low 2=normal 4=High. Default=2

;** AUTOIT3 settings
#AutoIt3Wrapper_Run_Debug_Mode=N					;(Y/N)Run Script with console debugging. Default=N

;** Target program Resource info
#AutoIt3Wrapper_Res_Description=X-Launcher - The Universal Launcher!
#AutoIt3Wrapper_Res_Fileversion_First_Increment=Y	; AutoIncrement: Before (Y); After (N) compile. Default=N
#AutoIt3Wrapper_Res_FileVersion_AutoIncrement=Y
#AutoIt3Wrapper_Res_Fileversion=2.0.0.345
#AutoIt3Wrapper_Res_ProductName=winPenPack X-Launcher_x64
#AutoIt3Wrapper_Res_ProductVersion=ISN Studio v1.16 / AutoIT v3.3.18.0
#AutoIt3Wrapper_Res_LegalCopyright=GNU General Public License
#AutoIt3Wrapper_Res_Language=2057			        ; Resource Lang code 1040=Italian. default 2057=English (GB) 
#AutoIt3Wrapper_Res_LegalTradeMarks=winPenPack ©
#AutoIt3Wrapper_Res_Comment=X-Launcher allows you to apply options to run programs to make them portable.
#AutoIt3Wrapper_Res_CompanyName=winPenPack
#AutoIt3Wrapper_Res_requestedExecutionLevel=None    ; None, asInvoker, highestAvailable or requireAdministrator (default=None)

#AutoIt3Wrapper_Res_Field=OriginalFilename|X-Launcher_x64.exe
; #AutoIt3Wrapper_Res_Field=ProductVersion|Ini Rev 5 x64
; #AutoIt3Wrapper_Res_Field=Authors|tittoproject - winPenPack Team & winPenPack community
; #AutoIt3Wrapper_Res_Field=eMail|winpenpack@gmail.com

#EndRegion

; Make this script high DPI aware
; AutoIt3Wrapper directive for exe files, DllCall for au3/a3x files
#AutoIt3Wrapper_Res_HiDpi=Y
If not @Compiled then DllCall("User32.dll", "bool", "SetProcessDPIAware")

;** Include X-Launcher's source code
#include 'x-launcher.au3'
#include 'files\x-install.au3'
