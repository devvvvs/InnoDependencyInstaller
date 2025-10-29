[Code]
// https://github.com/DomGries/InnoDependencyInstaller

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
  Dependency_NeedToRestart, Dependency_ForceX86, Dependency_IsX64, Dependency_IsArm64: Boolean;
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
procedure Dependency_InitializeWizard;
begin
  Dependency_DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

<event('PrepareToInstall')>
function Dependency_PrepareToInstall(var NeedsRestart: Boolean): String;
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
#ifdef Dependency_CustomExecute
          if {#Dependency_CustomExecute}(ExpandConstant('{tmp}{\}') + Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Parameters, ResultCode) then begin
#else
          if ShellExec('', ExpandConstant('{tmp}{\}') + Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Parameters, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then begin
#endif
            if Dependency_List[DependencyIndex].RestartAfter then begin
              if DependencyIndex = DependencyCount - 1 then begin
                Dependency_NeedToRestart := True;
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
              Dependency_NeedToRestart := True;
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

#ifndef Dependency_NoUpdateReadyMemo
<event('UpdateReadyMemo')>
#endif
function Dependency_UpdateReadyMemo(const Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
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
function Dependency_NeedRestart: Boolean;
begin
  Result := Dependency_NeedToRestart;
end;

function Dependency_String(const x86, x64, arm64: String): String;
begin
  if Dependency_IsArm64 then begin
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

function Dependency_IsNetCoreInstalled(Runtime: String; Major, Minor, Revision: Word): Boolean;
var
  Path: String;
  ResultCode: Integer;
  Output: TExecOutput;
  LineIndex: Integer;
  LineParts: TArrayOfString;
  PackedVersion: Int64;
  LineMajor, LineMinor, LineRevision, LineBuild: Word;
begin
  if not RegQueryStringValue(HKLM32, 'SOFTWARE\dotnet\Setup\InstalledVersions\' + Dependency_String('x86', 'x64', 'arm64'), 'InstallLocation', Path) or not FileExists(Path + 'dotnet.exe') then begin
    Path := ExpandConstant(Dependency_String('{commonpf32}', '{commonpf64}', '{commonpf}')) + '\dotnet\';
  end;
  if ExecAndCaptureOutput(Path + 'dotnet.exe', '--list-runtimes', '', SW_HIDE, ewWaitUntilTerminated, ResultCode, Output) and (ResultCode = 0) then begin
    for LineIndex := 0 to Length(Output.StdOut) - 1 do begin
      LineParts := StringSplit(Trim(Output.StdOut[LineIndex]), [' '], stExcludeEmpty);

      if (Length(LineParts) > 1) and (Lowercase(LineParts[0]) = Lowercase(Runtime)) and StrToVersion(LineParts[1], PackedVersion) then begin
        UnpackVersionComponents(PackedVersion, LineMajor, LineMinor, LineRevision, LineBuild);

        if (LineMajor = Major) and (LineMinor = Minor) and (LineRevision >= Revision) then begin
          Result := True;
          exit;
        end;
      end;
    end;
  end;
  Result := False;
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
  LineIndex: Integer;
  Lines: TArrayOfString;
  LineParts: TArrayOfString;
  InstalledVersion: String;
  RequiredMajor, RequiredMinor, RequiredPatch: Integer;
  InstalledMajor, InstalledMinor, InstalledPatch: Integer;
  VersionParts: TArrayOfString;
  InstalledVersionParts: TArrayOfString;
begin
  Result := False;
  
  if not ExecWithResult('dotnet', '--list-sdks', '', SW_HIDE, ewWaitUntilTerminated, ResultCode, ResultString) or (ResultCode <> 0) then
    Exit;
  
  // Parse required version (e.g., "8.0.413")
  VersionParts := StringSplit(Version, ['.'], stExcludeEmpty);
  if Length(VersionParts) < 3 then
    Exit;
  
  RequiredMajor := StrToIntDef(VersionParts[0], -1);
  RequiredMinor := StrToIntDef(VersionParts[1], -1);
  RequiredPatch := StrToIntDef(VersionParts[2], -1);
  
  if (RequiredMajor < 0) or (RequiredMinor < 0) or (RequiredPatch < 0) then
    Exit;
  
  // Parse output line by line
  Lines := StringSplit(ResultString, [#13#10], stExcludeEmpty);
  
  for LineIndex := 0 to Length(Lines) - 1 do begin
    LineParts := StringSplit(Trim(Lines[LineIndex]), [' '], stExcludeEmpty);

    // Each line format: "8.0.413 [C:\Program Files\dotnet\sdk]"
    if Length(LineParts) >= 1 then begin
      InstalledVersion := LineParts[0];
      InstalledVersionParts := StringSplit(InstalledVersion, ['.'], stExcludeEmpty);
      
      if Length(InstalledVersionParts) >= 3 then begin
        InstalledMajor := StrToIntDef(InstalledVersionParts[0], -1);
        InstalledMinor := StrToIntDef(InstalledVersionParts[1], -1);
        InstalledPatch := StrToIntDef(InstalledVersionParts[2], -1);
        
        // Check if installed SDK matches major.minor and has patch >= required
        if (InstalledMajor = RequiredMajor) and (InstalledMinor = RequiredMinor) and (InstalledPatch >= RequiredPatch) then begin
          Result := True;
          Exit;
        end;
      end;
    end;
  end;
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
var
  versionStr: String;
  file: String;
begin
  versionStr := '8.0.413';
  file := 'dotnet-sdk-' + versionStr + '-win-' + Dependency_String('x86', 'x64', 'arm64') + '.exe';
  // https://dotnet.microsoft.com/download/dotnet/8.0
  if not Dependency_IsNetSdkInstalled(versionStr) then begin
    Dependency_Add(
      file,
      '/install /quiet /norestart',
      '.NET SDK ' + versionStr + Dependency_ArchTitle,
      'https://builds.dotnet.microsoft.com/dotnet/Sdk/' + versionStr + '/' + file,
      '', False, False);
  end;
end;

procedure Dependency_AddVC2015To2022;
var
  file: String;
begin
  file := 'VC_redist.' + Dependency_String('x86', 'x64', 'arm64') + '.exe';
  // https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
  if not IsMsiProductInstalled(Dependency_String('{65E5BD06-6392-3027-8C26-853107D3CF1A}', '{36F68A90-239C-34DF-B58C-64B30153CE35}', '{DC9BAE42-810B-423A-9E25-E4073F1C7B00}'), PackVersionComponents(14, 44, 35211, 0)) then begin
    Dependency_Add(
      file,
      '/passive /norestart',
      'Visual C++ 2015-2022 Redistributable' + Dependency_ArchTitle,
      'https://aka.ms/vs/17/release/' + file,
      '', False, False);
  end;
end;

[Files]
#ifdef Dependency_Path_DirectX
Source: "{#Dependency_Path_DirectX}dxwebsetup.exe"; Flags: dontcopy noencryption
#endif
