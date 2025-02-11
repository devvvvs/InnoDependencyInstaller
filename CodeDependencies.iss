; https://github.com/DomGries/InnoDependencyInstaller


[Code]
// types and variables
type
  TDependency_Entry = record
    Filename: String;
    Parameters: String;
    Title: String;
    URL: String;
    Checksum: String;
    ForceSuccess: Boolean;
    RestartAfter: Boolean;
  end;

var
  Dependency_Memo: String;
  Dependency_List: array of TDependency_Entry;
  Dependency_NeedRestart, Dependency_ForceX86: Boolean;
  Dependency_DownloadPage: TDownloadWizardPage;

procedure Dependency_Add(const Filename, Parameters, Title, URL, Checksum: String; const ForceSuccess, RestartAfter: Boolean);
var
  Dependency: TDependency_Entry;
  DependencyCount: Integer;
begin
  Dependency_Memo := Dependency_Memo + #13#10 + '%1' + Title;

  Dependency.Filename := Filename;
  Dependency.Parameters := Parameters;
  Dependency.Title := Title;

  if FileExists(ExpandConstant('{tmp}{\}') + Filename) then begin
    Dependency.URL := '';
  end else begin
    Dependency.URL := URL;
  end;

  Dependency.Checksum := Checksum;
  Dependency.ForceSuccess := ForceSuccess;
  Dependency.RestartAfter := RestartAfter;

  DependencyCount := GetArrayLength(Dependency_List);
  SetArrayLength(Dependency_List, DependencyCount + 1);
  Dependency_List[DependencyCount] := Dependency;
end;

<event('InitializeWizard')>
procedure Dependency_Internal1;
begin
  Dependency_DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

<event('PrepareToInstall')>
function Dependency_Internal2(var NeedsRestart: Boolean): String;
var
  DependencyCount, DependencyIndex, ResultCode: Integer;
  Retry: Boolean;
  TempValue: String;
begin
  DependencyCount := GetArrayLength(Dependency_List);

  if DependencyCount > 0 then begin
    Dependency_DownloadPage.Show;

    for DependencyIndex := 0 to DependencyCount - 1 do begin
      if Dependency_List[DependencyIndex].URL <> '' then begin
        Dependency_DownloadPage.Clear;
        Dependency_DownloadPage.Add(Dependency_List[DependencyIndex].URL, Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Checksum);

        Retry := True;
        while Retry do begin
          Retry := False;

          try
            Dependency_DownloadPage.Download;
          except
            if Dependency_DownloadPage.AbortedByUser then begin
              Result := Dependency_List[DependencyIndex].Title;
              DependencyIndex := DependencyCount;
            end else begin
              case SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbError, MB_ABORTRETRYIGNORE, IDIGNORE) of
                IDABORT: begin
                  Result := Dependency_List[DependencyIndex].Title;
                  DependencyIndex := DependencyCount;
                end;
                IDRETRY: begin
                  Retry := True;
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    if Result = '' then begin
      for DependencyIndex := 0 to DependencyCount - 1 do begin
        Dependency_DownloadPage.SetText(Dependency_List[DependencyIndex].Title, '');
        Dependency_DownloadPage.SetProgress(DependencyIndex + 1, DependencyCount + 1);

        while True do begin
          ResultCode := 0;
          if ShellExec('', ExpandConstant('{tmp}{\}') + Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Parameters, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then begin
            if Dependency_List[DependencyIndex].RestartAfter then begin
              if DependencyIndex = DependencyCount - 1 then begin
                Dependency_NeedRestart := True;
              end else begin
                NeedsRestart := True;
                Result := Dependency_List[DependencyIndex].Title;
              end;
              break;
            end else if (ResultCode = 0) or Dependency_List[DependencyIndex].ForceSuccess then begin // ERROR_SUCCESS (0)
              break;
            end else if ResultCode = 1641 then begin // ERROR_SUCCESS_REBOOT_INITIATED (1641)
              NeedsRestart := True;
              Result := Dependency_List[DependencyIndex].Title;
              break;
            end else if ResultCode = 3010 then begin // ERROR_SUCCESS_REBOOT_REQUIRED (3010)
              Dependency_NeedRestart := True;
              break;
            end;
          end;

          case SuppressibleMsgBox(FmtMessage(SetupMessage(msgErrorFunctionFailed), [Dependency_List[DependencyIndex].Title, IntToStr(ResultCode)]), mbError, MB_ABORTRETRYIGNORE, IDIGNORE) of
            IDABORT: begin
              Result := Dependency_List[DependencyIndex].Title;
              break;
            end;
            IDIGNORE: begin
              break;
            end;
          end;
        end;

        if Result <> '' then begin
          break;
        end;
      end;

      if NeedsRestart then begin
        TempValue := '"' + ExpandConstant('{srcexe}') + '" /restart=1 /LANG="' + ExpandConstant('{language}') + '" /DIR="' + WizardDirValue + '" /GROUP="' + WizardGroupValue + '" /TYPE="' + WizardSetupType(False) + '" /COMPONENTS="' + WizardSelectedComponents(False) + '" /TASKS="' + WizardSelectedTasks(False) + '"';
        if WizardNoIcons then begin
          TempValue := TempValue + ' /NOICONS';
        end;
        RegWriteStringValue(HKA, 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', '{#SetupSetting("AppName")}', TempValue);
      end;
    end;

    Dependency_DownloadPage.Hide;
  end;
end;

<event('UpdateReadyMemo')>
function Dependency_Internal3(const Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := '';
  if MemoUserInfoInfo <> '' then begin
    Result := Result + MemoUserInfoInfo + Newline + NewLine;
  end;
  if MemoDirInfo <> '' then begin
    Result := Result + MemoDirInfo + Newline + NewLine;
  end;
  if MemoTypeInfo <> '' then begin
    Result := Result + MemoTypeInfo + Newline + NewLine;
  end;
  if MemoComponentsInfo <> '' then begin
    Result := Result + MemoComponentsInfo + Newline + NewLine;
  end;
  if MemoGroupInfo <> '' then begin
    Result := Result + MemoGroupInfo + Newline + NewLine;
  end;
  if MemoTasksInfo <> '' then begin
    Result := Result + MemoTasksInfo;
  end;

  if Dependency_Memo <> '' then begin
    if MemoTasksInfo = '' then begin
      Result := Result + SetupMessage(msgReadyMemoTasks);
    end;
    Result := Result + FmtMessage(Dependency_Memo, [Space]);
  end;
end;

<event('NeedRestart')>
function Dependency_Internal4: Boolean;
begin
  Result := Dependency_NeedRestart;
end;

function Dependency_IsX64: Boolean;
begin
  Result := not Dependency_ForceX86 and Is64BitInstallMode;
end;

function Dependency_String(const x86, x64, arm64: String): String;
begin
  if IsArm64 then begin
    Result := arm64;
  end else if Dependency_IsX64 then begin
    Result := x64;
  end else begin
    Result := x86;
  end;
end;

function Dependency_ArchSuffix: String;
begin
  Result := Dependency_String('', '_x64', '_arm64');
end;

function Dependency_ArchTitle: String;
begin
  Result := Dependency_String(' (x86)', ' (x64)', ' (arm64)');
end;

function Dependency_IsNetCoreInstalled(const Version: String): Boolean;
var
  ResultCode: Integer;
begin
  // source code: https://github.com/dotnet/deployment-tools/tree/main/src/clickonce/native/projects/NetCoreCheck
  if not FileExists(ExpandConstant('{tmp}{\}') + 'netcorecheck' + Dependency_ArchSuffix + '.exe') then begin
    ExtractTemporaryFile('netcorecheck' + Dependency_ArchSuffix + '.exe');
  end;
  Result := ShellExec('', ExpandConstant('{tmp}{\}') + 'netcorecheck' + Dependency_ArchSuffix + '.exe', Version, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

{ Exec with output stored in result. }
{ ResultString will only be altered if True is returned. }
function ExecWithResult(const Filename, Params, WorkingDir: String; const ShowCmd: Integer;
  const Wait: TExecWait; var ResultCode: Integer; var ResultString: String): Boolean;
var
  TempFilename: String;
  Command: String;
  TempResultString: AnsiString;
begin
  TempFilename := ExpandConstant('{tmp}\~execwithresult.txt');
  { Exec via cmd and redirect output to file. Must use special string-behavior to work. }
  Command :=
    Format('"%s" /S /C ""%s" %s > "%s""', [
      ExpandConstant('{cmd}'), Filename, Params, TempFilename]);
  Result := Exec(ExpandConstant('{cmd}'), Command, WorkingDir, ShowCmd, Wait, ResultCode);
  if not Result then
    Exit;
  LoadStringFromFile(TempFilename, TempResultString);  { Cannot fail }
  DeleteFile(TempFilename);
  ResultString := String(TempResultString);
end;

function Dependency_IsNetSdkInstalled(const Version: String): Boolean;
var
  ResultCode: Integer;
  ResultString: String;
begin
  Result := ExecWithResult('dotnet', '--list-sdks', '', SW_HIDE, ewWaitUntilTerminated, ResultCode, ResultString) and (ResultCode = 0) and (Pos(Version, ResultString) > 0);
end;

function Dependency_IsWinAppRuntimeInstalled(const Version: String): Boolean;
var
  argStr: String;
  ResultCode: Integer;
  ResultString: String;
begin
  argStr := '-Command "(Get-AppxPackage Microsoft.WinAppRuntime.DDLM.' + Version + ' | Where-Object { $_.Architecture -eq ''x64'' }).PackageFullName"';
  Result := ExecWithResult('powershell', argStr, '', SW_HIDE, ewWaitUntilTerminated, ResultCode, ResultString) and (ResultCode = 0) and (Pos(Version, ResultString) > 0);
end;

procedure Dependency_AddVC2013;
begin
  // https://support.microsoft.com/en-us/help/4032938
  if not IsMsiProductInstalled(Dependency_String('{B59F5BF1-67C8-3802-8E59-2CE551A39FC5}', '{20400CF0-DE7C-327E-9AE4-F0F38D9085F8}', ''), PackVersionComponents(12, 0, 40664, 0)) then begin
    Dependency_Add('vcredist2013' + Dependency_ArchSuffix + '.exe',
      '/passive /norestart',
      'Visual C++ 2013 Update 5 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://download.visualstudio.microsoft.com/download/pr/10912113/5da66ddebb0ad32ebd4b922fd82e8e25/vcredist_x86.exe', 'https://download.visualstudio.microsoft.com/download/pr/10912041/cee5d6bca2ddbcd039da727bf4acb48a/vcredist_x64.exe', ''),
      '', False, False);
  end;
end;

procedure Dependency_AddDotNet80Sdk;
begin
  // https://dotnet.microsoft.com/download/dotnet/8.0
  if not Dependency_IsNetSdkInstalled('8.0.4') then begin
    Dependency_Add('dotnet80sdk' + Dependency_ArchSuffix + '.exe',
      '/install /quiet /norestart',
      '.NET SDK 8.0.401' + Dependency_ArchTitle,
      
      Dependency_String(
      'https://download.visualstudio.microsoft.com/download/pr/523db424-b1cc-425d-97f5-bd0e9b0c7440/f04171a6d597780662d809107a13f44e/dotnet-sdk-8.0.401-win-x86.exe', 
      'https://download.visualstudio.microsoft.com/download/pr/f5f1c28d-7bc9-431e-98da-3e2c1bbd1228/864e152e374b5c9ca6d58ee953c5a6ed/dotnet-sdk-8.0.401-win-x64.exe',
      'https://download.visualstudio.microsoft.com/download/pr/f4f3c82d-4d24-4e01-87fe-67b6d9213f42/d33ef29315ad07d303993695f7b93479/dotnet-sdk-8.0.401-win-arm64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddWinAppRuntime;
begin
  // https://learn.microsoft.com/de-de/windows/apps/windows-app-sdk/downloads
  // use powershell to run: Get-AppxPackage Microsoft.WinAppRuntime.ddlm
  // this shows versions in the format 6000.373.1641 which is different to the versions shown on the page
  // for the following dependency check we use the highest of those numbers found 
  // after installing the latest version of the installer from the website
  if not Dependency_IsWinAppRuntimeInstalled('6000.373.1641*') then begin
    Dependency_Add('WindowsAppRuntimeInstall' + Dependency_ArchSuffix + '.exe',
      '--quiet',
      'Microsoft Windows App SDK runtime' + Dependency_ArchTitle,
      
      Dependency_String(
      'https://aka.ms/windowsappsdk/1.6/1.6.250108002/windowsappruntimeinstall-x86.exe', 
      'https://aka.ms/windowsappsdk/1.6/1.6.250108002/windowsappruntimeinstall-x64.exe',
      'https://aka.ms/windowsappsdk/1.6/1.6.250108002/windowsappruntimeinstall-arm64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddVC2015To2022;
begin
  // https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
  if not IsMsiProductInstalled(Dependency_String('{65E5BD06-6392-3027-8C26-853107D3CF1A}', '{36F68A90-239C-34DF-B58C-64B30153CE35}', '{DC9BAE42-810B-423A-9E25-E4073F1C7B00}'), PackVersionComponents(14, 30, 30704, 0)) then begin
    Dependency_Add('vcredist2022' + Dependency_ArchSuffix + '.exe',
      '/passive /norestart',
      'Visual C++ 2015-2022 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://aka.ms/vs/17/release/vc_redist.x86.exe', 'https://aka.ms/vs/17/release/vc_redist.x64.exe', 'https://aka.ms/vs/17/release/vc_redist.arm64.exe'),
      '', False, False);
  end;
end;

[Files]
#ifdef Dependency_Path_NetCoreCheck
; download netcorecheck.exe: https://www.nuget.org/packages/Microsoft.NET.Tools.NETCoreCheck.x86
; download netcorecheck_x64.exe: https://www.nuget.org/packages/Microsoft.NET.Tools.NETCoreCheck.x64
; download netcorecheck_arm64.exe: https://www.nuget.org/packages/Microsoft.NET.Tools.NETCoreCheck.arm64
Source: "{#Dependency_Path_NetCoreCheck}netcorecheck.exe"; Flags: dontcopy noencryption
Source: "{#Dependency_Path_NetCoreCheck}netcorecheck_x64.exe"; Flags: dontcopy noencryption
Source: "{#Dependency_Path_NetCoreCheck}netcorecheck_arm64.exe"; Flags: dontcopy noencryption
#endif
