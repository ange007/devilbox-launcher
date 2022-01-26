unit DevilBoxControl;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Generics.Collections, System.IniFiles, System.IOUtils, System.Net.Socket,
  System.Net.HttpClient, System.Net.Mime, System.Net.URLClient, System.Threading,
  System.JSON, System.StrUtils,

  FMX.Dialogs, FMX.Forms,

  {$IF DEFINED(LINUX) or DEFINED(MACOS)}
  POSIX.Stdlib
  {$ELSE}
  Winapi.Windows, Winapi.ShellApi, Winapi.TlHelp32,
  FMX.Platform.Win
  {$ENDIF};

type
  TDevilBoxControl = class(TObject)
  published
    constructor Create(const dockerPath, workPath: string);
    destructor Destroy;
  private
    {Paths}
    FDockerPath: string;
    FWorkPath: string;

    {Lists}
    FModules: TDictionary<string, TArray<string>>;
    FStartedModules: TList<string>;
    FOptions: TDictionary<string, Variant>;
    FDomains: TList<string>;

    {}
    FLoaderState: Boolean;
    FIsStarted: Boolean;

    {}
    FOnLoader: TProc<Boolean>;
    FOnStarted: TProc;
    FOnStopped: TProc;

    {}
    FHTTPClient: THTTPClient;

    {HTTP Events}
    procedure OnValidateCertificateCallback(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);

    {JSON}
    function CheckJSON(const JSON, key: string): Boolean;
    function GetJSONValue(const JSON, key: string): Variant;

    {Other}
    procedure Loader(const active: Boolean);
  public
    {Options}
    function ReadOptions: Boolean;

    {Domains}
    function ReadDomains: Boolean;
    function AddDomain(const name: string): string;
    function RemoveDomain(const name: string): Boolean;
    function OpenDomainDir(const name: string): string;

    {Modules}
    function SetModuleState(const module: string; const active: Boolean): Boolean;
    function SetModuleVersion(const module, version: string): Boolean;

    {System}
    function ProcessExists(const processName: string): Boolean;
    function RunCommand(const arg1, arg2, arg3: string): Integer;
    procedure RunCommandAndWait(const executeFile, paramString, startInString: string; const resultCallback: TProc<DWORD>; const showWindow: Boolean = False; const syncCallback: Boolean = False; const asAdmin: Boolean = False);

    {}
    procedure ApiRequest(const path: string; params: TMultipartFormData; const callback: TProc<Integer, string>; const sync: Boolean = True);

    {}
    function RebuildENV: Boolean;
    function Build: Boolean;
    procedure Run(const needRemove: Boolean = True);
    procedure Stop;
    procedure CheckRunState;

    {}
    procedure ImageUp(const services: TArray<string>; const needRemove: Boolean);
    procedure ImageDown(callback: TProc<Boolean>);
    procedure ImageRemove(callback: TProc<Boolean>);
    procedure ImageUpdate(callback: TProc<Boolean>);

    {}
    property DockerPath: string read FDockerPath;
    property WorkPath: string read FWorkPath;

    {}
    property Domains: TList<string> read FDomains write FDomains;
    property Modules: TDictionary<string, TArray<string>> read FModules;
    property Options: TDictionary<string, Variant> read FOptions{ write FOptions};
    property StartedModules: TList<string> read FStartedModules;

    property IsStarted: Boolean read FIsStarted write FIsStarted;
    property OnLoader: TProc<Boolean> read FOnLoader write FOnLoader;
    property OnStarted: TProc read FOnStarted write FOnStarted;
    property OnStopped: TProc read FOnStopped write FOnStopped;
  end;

{$IFDEF MSWINDOWS}
function IsUserAnAdmin: BOOL; stdcall; external 'shell32.dll' name 'IsUserAnAdmin';
{$ENDIF}

const
  ModuleNames: array[0..6] of string = (
    'PHP',
    'HTTPD',
    'MYSQL',
    'PGSQL',
    'REDIS',
    'MEMCD',
    'MONGO'
  );

implementation

{ TDockerControl }

constructor TDevilBoxControl.Create(const dockerPath, workPath: string);
var
  moduleName: string;
begin
  FLoaderState := False;

  FDockerPath := IncludeTrailingPathDelimiter(dockerPath);
  FWorkPath := IncludeTrailingPathDelimiter(workPath);

  {Init Modules}
  FModules := TDictionary<string, TArray<string>>.Create;
  for moduleName in ModuleNames do FModules.Add(moduleName, []);

  {Init Lists}
  FOptions := TDictionary<string, Variant>.Create;
  FDomains := TList<string>.Create;
  FStartedModules := TList<string>.Create;
  
  {HTTP client for Docker API}
  FHTTPClient := THTTPClient.Create;

  {HTTP Client config}
  with FHTTPClient do
  begin
    Accept := 'application/json';
    ConnectionTimeout := 5000;
    ResponseTimeout  := 5000;
    HandleRedirects := True;
    AllowCookies := False;
    OnValidateServerCertificate := OnValidateCertificateCallback;
  end;
end;

destructor TDevilBoxControl.Destroy;
begin
  FreeAndNil(FHTTPClient);
  FreeAndNil(FModules);
  FreeAndNil(FOptions);
  FreeAndNil(FDomains);
  FreeAndNil(FStartedModules);
end;

{

}

function TDevilBoxControl.ReadOptions: Boolean;
var
  i: Integer;
  envList: TStringList;
  moduleList: TArray<string>;
  envLine, envOptionName, envOptionValue, moduleName, moduleServer: string;
begin
  {Check ENV file}
  if not (FileExists(FWorkPath + '.env')) then
  begin
    ShowMessage('.env file not found in: ' + FWorkPath);
    Exit;
  end;

  {Read file}
  envList := TStringList.Create;
  envList.StrictDelimiter := True;
  envList.LoadFromFile(FWorkPath + '.env', TEncoding.UTF8);

  {Read options}
  for i := 0 to envList.Count - 1 do
  begin
    envOptionName := envList.Names[i].Trim;
    envOptionValue := envList.ValueFromIndex[i].Trim;  
    if (Pos('#', envOptionName) = 1) or (envOptionValue.IsEmpty) then Continue;

    FOptions.AddOrSetValue(envOptionName, envOptionValue);
  end;
  
  {Read modules}
  for moduleName in FModules.Keys do
  begin
    moduleServer := moduleName + '_SERVER';

    for i := 0 to envList.Count - 1 do
    begin
      envOptionName := envList.Names[i].Trim([' ', '#']);    
      envOptionValue := envList.ValueFromIndex[i].Trim; 
      if envOptionName <> moduleServer then Continue;

      FModules[moduleName] := FModules[moduleName] + [envOptionValue];
    end;
  end;

  {}
  FreeAndNil(envList);

  {}
  Result := True;
end;

function TDevilBoxControl.RebuildENV: Boolean;
var
  i: Integer;
  envList: TStringList;
  serverList: TArray<string>;
  module, moduleServer: string;
  envLine, envOptionName, envOptionValue: string;
  optionName, optionValue: string;
begin
  {Check ENV file}
  if not (FileExists(FWorkPath + '.env')) then
  begin
    Exit(False);
  end;

  {Read file}
  envList := TStringList.Create;
  envList.StrictDelimiter := True;
  envList.LoadFromFile(FWorkPath + '.env', TEncoding.UTF8);

  {}
  serverList := [];
  for module in FModules.Keys.ToArray do
  begin
    moduleServer := module + '_SERVER';

    {Add to server list}
    serverList := serverList + [moduleServer];

    {Clear options if module - disabled}
    // if not FStartedModules.Contains(LowerCase(module)) then FOptions.AddOrSetValue(moduleServer, '');
  end;

  {Save options to ENV}
  for i := 0 to envList.Count - 1 do
  begin
    envOptionName := envList.Names[i].Trim([' ', '#']);
    envOptionValue := envList.ValueFromIndex[i];
      
    for optionName in FOptions.Keys do
    begin
      if envOptionName <> optionName then Continue;
      optionValue := FOptions.Items[optionName];

      if MatchStr(envOptionName, serverList) then
      begin
        if optionValue <> envOptionValue then envList[i] := '#' + envOptionName + '=' + envOptionValue
        else envList[i] := envOptionName + '=' + envOptionValue;

        Break;
      end
      else
      begin
        envList.ValueFromIndex[i] := optionValue;
      end;
    end;
  end;

  {Save ENV file}
  envList.SaveToFile(FWorkPath + '.env', TEncoding.UTF8);
end;

{

}

function TDevilBoxControl.ReadDomains: Boolean;
var
  DList, FList: TStringDynArray;
  directory, fileName: string;
  LSearchOption: TSearchOption;
begin
  Result := False;
  LSearchOption := TSearchOption.soTopDirectoryOnly;

  try
    DList := TDirectory.GetDirectories(FWorkPath + 'data' + PathDelim + 'www', '*', LSearchOption);
    for directory in DList do FDomains.Add(ExtractFileName(directory));

    Result := True; 
  except end;
end;

function TDevilBoxControl.AddDomain(const name: string): string;
var
  path: string;
begin
  path := FWorkPath + 'data' + PathDelim + 'www' + PathDelim + name;
  
  if CreateDir(path) then
  begin
    FDomains.Add(name);

    Result := path;
  end;
end;

function TDevilBoxControl.RemoveDomain(const name: string): Boolean;
var
  path: string;
begin
  Result := False;
  if not FDomains.Contains(name) then Exit;

  path := FWorkPath + 'data' + PathDelim + 'www' + PathDelim + name;
  
  if RemoveDir(path) then
  begin
    FDomains.Remove(name);

    Result := True;
  end;
end;

function TDevilBoxControl.OpenDomainDir(const name: string): string;
var
  path: string;
begin
  Result := '';
  // if not FDomains.Contains(name) then Exit;

  path := FWorkPath + 'data' + PathDelim + 'www' + PathDelim + name;
  RunCommand('open', path, '');
end;

{
  Module
}

function TDevilBoxControl.SetModuleState(const module: string; const active: Boolean): Boolean;
var
  aliases: TDictionary<string, string>;
  moduleName, moduleServer: string;
begin
  moduleName := LowerCase(module);
  moduleServer := UpperCase(module);

  if not FModules.ContainsKey(moduleServer) then Exit(False)
  else Result := True;

  if not (active) and (FStartedModules.IndexOf(moduleName) >= 0) then FStartedModules.Remove(moduleName)
  else if active and (FStartedModules.IndexOf(moduleName) < 0) then FStartedModules.Add(moduleName);
end;

function TDevilBoxControl.SetModuleVersion(const module, version: string): Boolean;
begin
  if not FModules.ContainsKey(UpperCase(module)) then Exit(False)
  else Result := True;

  FOptions.AddOrSetValue(UpperCase(module) + '_SERVER', version);
end;

{
  System
}

function TDevilBoxControl.ProcessExists(const processName: string): Boolean;
{$IFDEF MSWINDOWS}
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := False;
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(processName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(processName))) then
    begin
      Result := True;
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
{$ELSE}
begin
  Result := False;
{$ENDIF}
end;

function TDevilBoxControl.RunCommand(const arg1, arg2, arg3: string): Integer;
begin
  {$IF DEFINED(MACOS)}
  Result := _system(PAnsiChar(AnsiString(arg1 + ' ' + arg2 + ' ' + arg3)));
  {$ELSEIF Defined(IOS)}
  Result := SharedApplication.OpenURL(StrToNSUrl(URL));
  {$ELSEIF DEFINED(LINUX)}
  Result := _system(MarshaledAString(UTF8String(arg1 + ' ' + arg2 + ' ' + arg3)));
  {$ELSEIF Defined(ANDROID)}
  Intent := TJIntent.Create;
  Intent.setAction(TJIntent.JavaClass.ACTION_VIEW);
  Intent.setData(StrToJURI(URL));
  Result := TAndroidHelper.Activity.startActivity(Intent);
  {$ELSE}
  Result := ShellExecute(0, PChar(arg1), PChar(arg2), PChar(arg3), nil, SW_SHOWNORMAL);
  {$ENDIF}
end;

procedure TDevilBoxControl.RunCommandAndWait(const executeFile, paramString, startInString: string; const resultCallback: TProc<DWORD>; const showWindow, syncCallback, asAdmin: Boolean);
begin
  TTask.Run(procedure
  {$IFDEF MSWINDOWS}
    var
    SEInfo: TShellExecuteInfo;
    shellState: DWORD;
  {$ENDIF}
  begin
    {$IFDEF MSWINDOWS}
    FillChar(SEInfo, SizeOf(SEInfo), 0);
    SEInfo.cbSize := SizeOf(SEInfo);
    with SEInfo do
    begin
      Wnd := ApplicationHWND;
      lpFile := PChar(executeFile);
      lpParameters := PChar(paramString);
      fMask := SEE_MASK_FLAG_DDEWAIT or SEE_MASK_FLAG_NO_UI or SEE_MASK_NOCLOSEPROCESS;

      if not startInString.IsEmpty then lpDirectory := PChar(startInString);
      if asAdmin then lpVerb := 'runas';

      if showWindow then nShow := SW_SHOWNORMAL
      else nShow := SW_HIDE;
    end;
  
    if ShellExecuteEx(@SEInfo) then
    begin
      repeat
        Application.ProcessMessages;
        GetExitCodeProcess(SEInfo.hProcess, shellState);
      until (shellState <> STILL_ACTIVE) or Application.Terminated;

      if Assigned(resultCallback) then
      begin
         if syncCallback then TThread.Synchronize(nil, procedure begin resultCallback(shellState); end)
         else resultCallback(shellState);
      end;
    end
    else
    begin
       if Assigned(resultCallback) then
      begin
         if syncCallback then TThread.Synchronize(nil, procedure begin resultCallback(WAIT_FAILED); end)
         else resultCallback(WAIT_FAILED);
      end;
    end;
  {$ENDIF}
  end);
end;

{
  Docker API
}

{Request CERT control}
procedure TDevilBoxControl.OnValidateCertificateCallback(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);
begin
  Accepted := True;
end;

{API Request}
procedure TDevilBoxControl.ApiRequest(const path: string; params: TMultipartFormData; const callback: TProc<Integer, string>; const sync: Boolean = True);
begin
  params := TMultipartFormData.Create;

  with FHTTPClient do
  begin
    {Show Loader if needed}
    Loader(True);

    {Send request}
    try
      BeginGet(procedure(const Value: IAsyncResult)
      var
        response: IHTTPResponse;
      begin
        try
          try
            response := THTTPClient.EndAsyncHTTP(Value);
          except
            if sync then TThread.Synchronize(nil, procedure begin callback(0, ''); end)
            else callback(0, '');

            Exit;
          end;

          {$IFDEF DEBUG}
          // TThread.Synchronize(nil, procedure begin TDialogService.ShowMessage(response.ContentAsString); end);
          {$ENDIF}

          if sync then TThread.Synchronize(nil, procedure begin callback(response.StatusCode, response.ContentAsString); end)
          else callback(response.StatusCode, response.ContentAsString);
        finally
          {Hide Loader}
          TThread.Synchronize(nil, procedure begin Loader(False); end);

          response := nil;
          FreeAndNil(params);
        end;
      end,
      'http://localhost:2375/v1.41/' + path{, params});
    except end;
  end;
end;

{Read JSON}
function TDevilBoxControl.GetJSONValue(const JSON, key: string): Variant;
var
  JSONObj: TJSONObject;
  JSONValue: TJSONValue;
begin
  Result := False;
  JSONObj := TJSONObject.ParseJSONValue(JSON) as TJSONObject;

  if Assigned(JSONObj) then
  begin
    try
      JSONValue := JSONObj.FindValue(key);

      if Assigned(JSONValue) then
      begin
        try
          if JSONValue is TJSONTrue then Result := True
          else if JSONValue is TJSONFalse then Result := False
          else if JSONValue is TJSONNumber then Result := (JSONValue as TJSONNumber).AsInt64
          else if JSONValue is TJSONObject then Result := JSONValue.ToString
          else if JSONValue is TJSONArray then Result := JSONValue.ToString
          else Result := JSONValue.Value;
        except end;
      end;
    finally
      FreeAndNil(JSONObj);
      JSONValue := nil;
    end;
  end;
end;

{Check JSON}
function TDevilBoxControl.CheckJSON(const JSON, key: string): Boolean;
var
  value: Variant;
begin
  value := GetJSONValue(JSON, key);
  Result := not (VarIsEmpty(value)) and not (value.isEmpty);
end;

{

}

function TDevilBoxControl.Build: Boolean;
begin
  {Build options}
  RebuildENV;
end;

procedure TDevilBoxControl.Run(const needRemove: Boolean);
var
  isDockerRun: Boolean;
  startedModules: TArray<string>;
begin
  if FStartedModules.Count > 0 then startedModules := FStartedModules.ToArray
  else startedModules := ['httpd', 'php', 'mysql'];

  {Show Loader if needed}
  Loader(True);

  {$IFDEF MSWINDOWS}
  {Start Docker}
  if IsUserAnAdmin then
  begin
    RunCommandAndWait('net stop winnat', '', '', procedure(state: DWORD)
    begin
      RunCommandAndWait('docker start', '', '', procedure(state: DWORD)
      begin
        RunCommandAndWait('net start winnat', '', '', nil, True);
      end, True);
    end, True);
  end;

  {Check Run}
  isDockerRun := ProcessExists('Docker Desktop.exe');

  {Run containers}
  if not isDockerRun then RunCommandAndWait('Docker Desktop.exe', '', FDockerPath, procedure(state: DWORD) begin ImageUp(startedModules, needRemove); end)
  else ImageUp(startedModules, needRemove);
  {$ENDIF}
end;

procedure TDevilBoxControl.Stop;
begin
  ImageDown(nil);
end;

procedure TDevilBoxControl.ImageUp(const services: TArray<string>; const needRemove: Boolean);
var
  lastState: DWORD;
  upProcedure: TProc;
begin
  {Before need run stop commands}
  ImageDown(procedure(state: Boolean)
  begin
    {Show Loader if needed}
    Loader(True);

    {Start commands}
    upProcedure := procedure
    begin
      RunCommandAndWait('docker-compose', 'up -d ' + string.Join(' ', services), FWorkPath, procedure(state: DWORD)
      begin
        {Hide Loader}
        Loader(False);

        {Check State}
        if state <> WAIT_OBJECT_0 then
        begin
          ShowMessage('DevilBox container build - failed!');
          Exit;
        end;

        {}
        FIsStarted := True;

        {Started callback}
        if Assigned(FOnStarted) then FOnStarted;
      end, True, True);
    end;

    {}
    if needRemove then ImageRemove(procedure(state: Boolean) begin upProcedure; end)
    else upProcedure;
  end);
end;

procedure TDevilBoxControl.ImageDown(callback: TProc<Boolean>);
var
  stopCommand: string;
begin
  {$IFDEF MSWINDOWS}
  stopCommand := 'cmd /c @echo off & FOR /f "tokens=*" %i IN (''docker ps -q'') DO docker stop %i';
  {$ELSE}
  stopCommand := 'docker stop $(docker ps -q)';
  {$ENDIF}

  {Show Loader if needed}
  Loader(True);

  {Start commands}
  RunCommandAndWait('cmd', stopCommand, '', procedure(state: DWORD)
  begin
    RunCommandAndWait('docker-compose', 'stop', FWorkPath, procedure(state: DWORD)
    begin
      FIsStarted := False;

      {Stopped callback}
      if Assigned(FOnStopped) then FOnStopped;

      {Additional callback}
      if Assigned(callback) then callback(state = WAIT_OBJECT_0);

      {Hide Loader}
      Loader(False);
    end, True);
  end, True);
end;

procedure TDevilBoxControl.ImageRemove(callback: TProc<Boolean>);
begin
  {Start commands}
  RunCommandAndWait('docker-compose', 'rm -s -f', FWorkPath, procedure(state: DWORD)
  begin
    if Assigned(callback) then callback(state = WAIT_OBJECT_0);
  end, True);
end;

procedure TDevilBoxControl.ImageUpdate(callback: TProc<Boolean>);
begin
  {Start commands}
  RunCommandAndWait('update-docker.sh', '', FWorkPath, procedure(state: DWORD)
  begin
    if Assigned(callback) then callback(state = WAIT_OBJECT_0);
  end, True);
end;

{

}

procedure TDevilBoxControl.CheckRunState;
begin
  FIsStarted := False;

  ApiRequest('/containers/json?filters={"name":["devilbox"],"status":["running"]}', nil, procedure(status: Integer; msg: string)
  begin
    FIsStarted := Length(msg) > 3;

    if FIsStarted and Assigned(FOnStarted) then FOnStarted
    else if Assigned(FOnStopped) then FOnStopped;
  end);
end;

{

}

procedure TDevilBoxControl.Loader(const active: Boolean);
begin
  {Show Loader if needed}
  if Assigned(FOnLoader) and (FLoaderState <> active) then FOnLoader(active);

  {Save actual state}
  FLoaderState := active;
end;

end.

