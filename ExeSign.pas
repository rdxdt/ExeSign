unit ExeSign;

interface

uses
  Windows,
  ShellApi,
  Classes,
  TLHelp32,
  System.SysUtils;

const
  EXE_NOT_SIGNED = 'NOTSIGNED';

function LoadSignature(fName: String): string;
function LoadSelfSignature(SelfHandle: THandle): string;
function WriteSignature(fName: string; Signature: string): boolean;
function processExists(exeFileName: string): boolean;
procedure SelfSign(hwid: string);

implementation

function WriteSignature(fName: string; Signature: string): boolean;
var
  ResourceHandle: THandle;
begin
  Result := false;
  ResourceHandle := BeginUpdateResourceW(PWideChar(fName), false);
  if ResourceHandle = 0 then
    Exit;
  Result := UpdateResourceW(ResourceHandle, MakeIntResource(10), '10357d55d2',
    0, PWideChar(Signature), (Length(Signature) + 1) * SizeOf(Signature[1]));
  EndUpdateResourceW(ResourceHandle, false);
end;

function LoadSignature(fName: String): string;
var
  ResourceLocation: HRSRC;
  ResourceSize: dword;
  ResourceHandle, ExeHandle: THandle;
  ResourcePointer: pointer;
begin
  try
    ExeHandle := LoadLibrary(PWideChar(fName));
    ResourceLocation := FindResource(ExeHandle, '10357d55d2', RT_RCDATA);
    ResourceSize := SizeofResource(ExeHandle, ResourceLocation);
    ResourceHandle := LoadResource(ExeHandle, ResourceLocation);
    ResourcePointer := LockResource(ResourceHandle);
    if ResourcePointer <> nil then
    begin
      SetLength(Result, ResourceSize - 1);
      CopyMemory(@Result[1], ResourcePointer, ResourceSize);
      FreeResource(ResourceHandle);
    end
    else
    begin
      Result := 'NOTSIGNED';
    end;
    if ExeHandle <> 0 then
      FreeLibrary(ExeHandle);
  except
    on E: Exception do
      Result := 'Error reading signature:' + E.Message;

  end;
end;

function LoadSelfSignature(SelfHandle: THandle): string;
var
  ResourceLocation: HRSRC;
  ResourceSize: dword;
  ResourceHandle, ExeHandle: THandle;
  ResourcePointer: pointer;
begin
  try
    ExeHandle := SelfHandle;
    ResourceLocation := FindResource(ExeHandle, '10357d55d2', RT_RCDATA);
    ResourceSize := SizeofResource(ExeHandle, ResourceLocation);
    ResourceHandle := LoadResource(ExeHandle, ResourceLocation);
    ResourcePointer := LockResource(ResourceHandle);
    if ResourcePointer <> nil then
    begin
      SetLength(Result, ResourceSize - 1);
      CopyMemory(@Result[1], ResourcePointer, ResourceSize);
      FreeResource(ResourceHandle);
    end
    else
    begin
      Result := 'NOTSIGNED';
    end;
    if ExeHandle <> 0 then
      FreeLibrary(ExeHandle);
  except
    on E: Exception do
      Result := 'Error reading signature:' + E.Message;

  end;
end;

function processExists(exeFileName: string): boolean;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := false;
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile))
      = UpperCase(exeFileName)) or (UpperCase(FProcessEntry32.szExeFile)
      = UpperCase(exeFileName))) then
    begin
      Result := True;
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

procedure SelfSign(hwid: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  CopyFile(PWideChar(ParamStr(0)), PWideChar(ChangeFileExt(ParamStr(0),
    '.tmp')), false);
  if WriteSignature(ChangeFileExt(ParamStr(0), '.tmp'), hwid) then
  begin
    SL.Add('TASKKILL /F /IM ' + ExtractFileName(ParamStr(0)));
    SL.Add('DEL /Q ' + ChangeFileExt(ParamStr(0), '.bak'));
    SL.Add('REN ' + ExtractFileName(ParamStr(0)) + ' ' +
      ExtractFileName(ChangeFileExt(ParamStr(0), '.bak')));
    // SL.Add('DEL /Q '+ExtractFileName(ParamStr(0));
    SL.Add('REN ' + ExtractFileName(ChangeFileExt(ParamStr(0), '.tmp')) + ' ' +
      ExtractFileName(ParamStr(0)));
    SL.Add('DEL "%~f0"');
    SL.SaveToFile(ExtractFilePath(ParamStr(0)) + '\temp.bat');
    ShellExecute(0, 'open', PWideChar(ExtractFilePath(ParamStr(0)) +
      '\temp.bat'), '', PWideChar(ExtractFilePath(ParamStr(0))), SW_HIDE);
  end;

end;

end.
