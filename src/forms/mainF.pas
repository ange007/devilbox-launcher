unit mainF;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Generics.Collections, System.Math, System.IniFiles, System.IOUtils,

  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.ListBox, FMX.TabControl,
  FMX.Edit, FMX.Layouts, FMX.Objects, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,
  FMX.NumberBox,

  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}

  DevilBoxControl, FMX.Menus;

type
  TFMain = class(TForm)
    tc_main: TTabControl;
    ti_main: TTabItem;
    ti_domains: TTabItem;
    ti_modules: TTabItem;
    grdpnlyt_main: TGridPanelLayout;
    lbl_work_path: TLabel;
    e_work_path: TEdit;
    pnl_actions: TPanel;
    lb_domains: TListBox;
    pnl_domains: TPanel;
    btn_domain_add: TButton;
    btn_domain_remove: TButton;
    ti_options: TTabItem;
    grdpnlyt_modules: TGridPanelLayout;
    lbl_docker_bin_path: TLabel;
    e_docker_path: TEdit;
    btn_close: TButton;
    btn_save: TButton;
    btn_save_build: TButton;
    sbook: TStyleBook;
    btn_stop: TButton;
    lyt_loader: TLayout;
    rctngl_loader: TRectangle;
    ani_loader: TAniIndicator;
    btn_open_panel: TButton;
    ti_debug: TTabItem;
    m_debug: TMemo;
    btn_update: TButton;
    cb_remove_images: TCheckBox;
    btn_domains_reload: TButton;
    pnl_options: TPanel;
    btn_open_work_path: TButton;
    btn_open_hosts: TButton;
    btn_open_domain_path: TButton;
    grdpnlyt_options: TGridPanelLayout;
    vrtscrlbx_modules: TVertScrollBox;
    vrtscrlbx_options: TVertScrollBox;
    cb_write_hosts: TCheckBox;
    pm_domain: TPopupMenu;
    mni_domain_open_dir: TMenuItem;
    mni_domain_shell: TMenuItem;
    mni_open_url: TMenuItem;
    btn_shell: TButton;
    {}
    procedure OnChangeOptionValue(Sender: TObject);
    procedure OnChangeModuleState(Sender: TObject);
    procedure OnChangeModuleVersion(Sender: TObject);
    {}
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    {}
    procedure btn_saveClick(Sender: TObject);
    procedure e_work_pathDblClick(Sender: TObject);
    procedure btn_domain_addClick(Sender: TObject);
    procedure btn_domain_removeClick(Sender: TObject);
    procedure e_docker_pathDblClick(Sender: TObject);
    {}
    procedure btn_closeClick(Sender: TObject);
    procedure btn_save_buildClick(Sender: TObject);
    procedure btn_stopClick(Sender: TObject);
    procedure btn_domains_open_dirClick(Sender: TObject);
    procedure btn_open_panelClick(Sender: TObject);
    procedure btn_updateClick(Sender: TObject);
    procedure btn_domains_reloadClick(Sender: TObject);
    procedure btn_open_hostsClick(Sender: TObject);
    procedure btn_open_domain_pathClick(Sender: TObject);
    procedure btn_open_work_pathClick(Sender: TObject);
    procedure mni_domain_open_dirClick(Sender: TObject);
    procedure lb_domainsDblClick(Sender: TObject);
    procedure btn_shellClick(Sender: TObject);
    procedure mni_open_urlClick(Sender: TObject);
  private
    FDevilBoxControl: TDevilBoxControl;
    FIsInit: Boolean;

    function Init: Boolean;

    function ReadOptions: Boolean;
    function ReadDomains: Boolean;
  public
    { Public declarations }
  end;

var
  FMain: TFMain;

implementation

{$R *.fmx}

procedure TFMain.btn_domain_addClick(Sender: TObject);
var
  domainName: string;
begin
  if InputQuery('Add domain name', 'Domain Name:', domainName)  then
  begin
    if FDevilBoxControl.AddDomain(domainName) <> '' then lb_domains.Items.Add(domainName);
  end;
end;

procedure TFMain.btn_domain_removeClick(Sender: TObject);
begin
  if lb_domains.ItemIndex < 0 then Exit;

  MessageDlg('Delete?', TMsgDlgType.mtWarning, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrYes then Abort;

      if FDevilBoxControl.RemoveDomain(lb_domains.Selected.Text) then
      begin
        lb_domains.Selected.Destroy;
      end;
    end);
end;

procedure TFMain.btn_domains_open_dirClick(Sender: TObject);
begin
  FDevilBoxControl.OpenDomainDir('');
end;

procedure TFMain.btn_domains_reloadClick(Sender: TObject);
begin
  FDevilBoxControl.ReadDomains;
end;

procedure TFMain.btn_open_domain_pathClick(Sender: TObject);
begin
  FDevilBoxControl.OpenDomainDir('');
end;

procedure TFMain.btn_open_hostsClick(Sender: TObject);
begin
  FDevilBoxControl.RunCommand('open', FDevilBoxControl.GetHostsFileName, '');
end;

procedure TFMain.btn_open_panelClick(Sender: TObject);
begin
  FDevilBoxControl.RunCommand('open', 'http://localhost', '');
end;

procedure TFMain.btn_open_work_pathClick(Sender: TObject);
begin
  FDevilBoxControl.RunCommand('open', e_work_path.Text, '');
end;

procedure TFMain.btn_saveClick(Sender: TObject);
begin
  if Init then
  begin
    FDevilBoxControl.Build(cb_write_hosts.IsChecked);
  end;
end;

procedure TFMain.btn_save_buildClick(Sender: TObject);
begin
  if Init then
  begin
    FDevilBoxControl.Build(cb_write_hosts.IsChecked);
    FDevilBoxControl.Run(cb_remove_images.IsChecked);
  end;
end;

procedure TFMain.btn_shellClick(Sender: TObject);
begin
  FDevilBoxControl.RunCommandAndWait({$IFDEF MSWINDOWS}'shell.bat'{$ELSE}'shell.sh'{$ENDIF}, '', FDevilBoxControl.WorkPath, nil, True);
end;

procedure TFMain.btn_stopClick(Sender: TObject);
begin
  FDevilBoxControl.Stop;
end;

procedure TFMain.btn_updateClick(Sender: TObject);
begin
  FDevilBoxControl.ImageUpdate(procedure(state: Boolean)
  begin
    if not (state) then Exit;

    {Read Options}
    FDevilBoxControl.ReadOptions;
  end);
end;

procedure TFMain.btn_closeClick(Sender: TObject);
begin
  Close;
end;

procedure TFMain.e_docker_pathDblClick(Sender: TObject);
var
  dir: string;
begin
  if SelectDirectory('Select Docker Directory', '', dir) then
  begin
    e_docker_path.Text := dir;
    Init;
  end;
end;

procedure TFMain.e_work_pathDblClick(Sender: TObject);
var
  dir: string;
begin
  if SelectDirectory('Select DevilBox Directory', '', dir) then
  begin
    e_work_path.Text := dir;
    Init;
  end;
end;

procedure TFMain.mni_domain_open_dirClick(Sender: TObject);
begin
  if lb_domains.ItemIndex < 0 then Exit;

  FDevilBoxControl.OpenDomainDir(lb_domains.Selected.Text);
end;

procedure TFMain.mni_open_urlClick(Sender: TObject);
begin
  if lb_domains.ItemIndex < 0 then Exit;

  FDevilBoxControl.RunCommand('open', 'http://' + lb_domains.Selected.Text + '.' + FDevilBoxControl.GetOption('TLD_SUFFIX'), '');
end;

{

}

procedure TFMain.OnChangeOptionValue(Sender: TObject);
var
  edit: TEdit;
begin
  edit := (Sender as TEdit);

  FDevilBoxControl.SetOption(edit.TagString, edit.Text);
end;

procedure TFMain.OnChangeModuleState(Sender: TObject);
var
  checkBox: TCheckBox;
begin
  checkBox := (Sender as TCheckBox);

  FDevilBoxControl.SetModuleState(checkBox.TagString, checkBox.IsChecked);
end;

procedure TFMain.OnChangeModuleVersion(Sender: TObject);
var
  comboBox: TComboBox;
  module, value: string;
begin
  comboBox := (Sender as TComboBox);
  if comboBox.ItemIndex < 0 then Exit;

  module := comboBox.TagString;
  value := comboBox.Selected.Text;

  FDevilBoxControl.SetModuleVersion(module, value);
end;

{

}

procedure TFMain.FormClose(Sender: TObject; var Action: TCloseAction);
var
  i, j: Integer;
  moduleCheckBox: TCheckBox;
begin
  {Save options}
  with TIniFile.Create('./launcher.ini') do
  begin
    WriteString('options', 'work_path', e_work_path.Text);
    WriteString('options', 'docker_path', e_docker_path.Text);
    WriteBool('options', 'remove_images', cb_remove_images.IsChecked);
    WriteBool('options', 'write_hosts', cb_write_hosts.IsChecked);

    for i := 0 to grdpnlyt_modules.ControlsCount - 1 do
    begin
      if not (grdpnlyt_modules.Controls[i] is TLayout) then Continue;

      for j := 0 to grdpnlyt_modules.Controls[i].ControlsCount - 1 do
      begin
        if not (grdpnlyt_modules.Controls[i].Controls[j] is TCheckBox) then Continue;

        moduleCheckBox := grdpnlyt_modules.Controls[i].Controls[j] as TCheckBox;
        WriteBool('modules', moduleCheckBox.TagString, moduleCheckBox.IsChecked);
      end;
    end;

    Free;
  end;

  {}
  FreeAndNil(FDevilBoxControl);
end;

procedure TFMain.FormCreate(Sender: TObject);
var
  i, j: Integer;
  moduleCheckBox: TCheckBox;
begin
  {}
  tc_main.ActiveTab := ti_domains;

  {Init}
  Init;

  {Load options}
  with TIniFile.Create('./launcher.ini') do
  begin
    e_work_path.Text := ReadString('options', 'work_path', '');
    e_docker_path.Text := ReadString('options', 'docker_path', '');
    cb_remove_images.IsChecked := ReadBool('options', 'remove_images', True);
    cb_write_hosts.IsChecked := ReadBool('options', 'write_hosts', True);

    for i := 0 to grdpnlyt_modules.ControlsCount - 1 do
    begin
      if not (grdpnlyt_modules.Controls[i] is TLayout) then Continue;

      for j := 0 to grdpnlyt_modules.Controls[i].ControlsCount - 1 do
      begin
        if not (grdpnlyt_modules.Controls[i].Controls[j] is TCheckBox) then Continue;

        moduleCheckBox := grdpnlyt_modules.Controls[i].Controls[j] as TCheckBox;
        moduleCheckBox.IsChecked := ReadBool('modules', moduleCheckBox.TagString, True);
      end;
    end;

    Free;
  end;
end;

function TFMain.Init: Boolean;
begin
  if FIsInit then Exit(True);
  
  {Check directories}
  if e_work_path.Text.IsEmpty or e_docker_path.Text.IsEmpty then
  begin
    tc_main.ActiveTab := ti_main;

    ShowMessage('Please select DevilBox and Docker path!');
    Exit;
  end;

  {}
  FDevilBoxControl := TDevilBoxControl.Create(e_docker_path.Text, e_work_path.Text);

  {}
  FDevilBoxControl.OnLoader := procedure(show: Boolean)
  begin
    lyt_loader.Visible := show;
    if lyt_loader.Visible then lyt_loader.BringToFront;
  end;

  {}
  FDevilBoxControl.OnStarted := procedure
  begin
    btn_stop.Visible := True;
    btn_open_panel.Visible := True;
    btn_shell.Visible := True;
  end;

  {}
  FDevilBoxControl.OnStopped := procedure
  begin
    btn_stop.Visible := False;
    btn_open_panel.Visible := False;
    btn_shell.Visible := False;
  end;

  {Check state}
  FDevilBoxControl.CheckRunState;

  {Read Domains}
  ReadDomains;

  {Read Options and Modules}
  ReadOptions;

  {}
  FIsInit := True;
  Result := True;
end;

procedure TFMain.lb_domainsDblClick(Sender: TObject);
begin
  mni_domain_open_dirClick(nil);
end;

function TFMain.ReadOptions: Boolean;

  procedure outputOptions;
  var
    lbl: TLabel;
    edit: TEdit;
    number: TNumberBox;
    optionIdentify: string;
    value: Variant;
    rowItem: TGridPanelLayout.TRowItem;
    rowIndex, insertIndex: Integer;
  begin
    rowIndex := 0;
    insertIndex := 0;

    {}
    grdpnlyt_options.RowCollection.ClearAndResetID;

    {}
    for optionIdentify in FDevilBoxControl.Options.Keys do
    begin
      if Pos('_SERVER', optionIdentify) = (Length(optionIdentify) - Length('_SERVER') + 1) then Continue;

      {Read Option}
      FDevilBoxControl.Options.TryGetValue(optionIdentify, value);

      {Add Row}
      rowItem := grdpnlyt_options.RowCollection.Add;
      rowItem.SizeStyle := TGridPanelLayout.TSizeStyle.Absolute;
      rowItem.Value := 28;

      {Label}
      lbl := TLabel.Create(grdpnlyt_options);
      lbl.Parent := grdpnlyt_options;
      lbl.Text := optionIdentify + ': ';
      lbl.Align := TAlignLayout.Client;

      {}
      edit := TEdit.Create(grdpnlyt_options);
      edit.Parent := grdpnlyt_options;
      edit.Align := TAlignLayout.Client;
      edit.TagString := optionIdentify;
      edit.Text := value;
      edit.OnChange := OnChangeOptionValue;

      {}
      Inc(insertIndex);
    end;

    grdpnlyt_options.Height := 10 + (rowItem.Value * insertIndex);
  end;

  procedure outputModules;
  var
    lyt: TLayout;
    lbl: TLabel;
    comboBox: TComboBox;
    checkBox: TCheckBox;
    module, moduleServer, optionIdentify: string;
    value: Variant;
    rowItem: TGridPanelLayout.TRowItem;
    rowIndex, insertIndex: Integer;
  begin
    rowIndex := 0;
    insertIndex := 0;

    {}
    grdpnlyt_modules.RowCollection.ClearAndResetID;

    {}
    for module in FDevilBoxControl.Modules.Keys do
    begin
      moduleServer := module + '_SERVER';

      {Read Option}
      FDevilBoxControl.Options.TryGetValue(moduleServer, value);

      {Add Row}
      if (grdpnlyt_modules.ControlsCount <= 0)
        or (grdpnlyt_modules.ControlsCount >= (grdpnlyt_modules.RowCollection.Count * grdpnlyt_modules.ColumnCollection.Count)) then
      begin
        rowItem := grdpnlyt_modules.RowCollection.Add;
        rowItem.SizeStyle := TGridPanelLayout.TSizeStyle.Absolute;
        rowItem.Value := 52;
      end;

      {}
      lyt := TLayout.Create(grdpnlyt_modules);
      lyt.Parent := grdpnlyt_modules;
      lyt.Align := TAlignLayout.Client;

      {Label}
      lbl := TLabel.Create(lyt);
      lbl.Parent := lyt;
      lbl.Text := module + ': ';
      lbl.Align := TAlignLayout.Top;

      {}
      checkBox := TCheckBox.Create(lyt);
      checkBox.Parent := lyt;
      checkBox.Align := TAlignLayout.Left;
      checkBox.Width := 25;
      checkBox.OnChange := OnChangeModuleState;
      checkBox.TagString := module;
      checkBox.IsChecked := not VarIsNull(value) and not VarIsEmpty(value);

      {}
      comboBox := TComboBox.Create(lyt);
      comboBox.Parent := lyt;
      comboBox.Align := TAlignLayout.Client;
      comboBox.OnChange := OnChangeModuleVersion;
      comboBox.TagString := module;

      {}
      for optionIdentify in FDevilBoxControl.Modules.Items[module] do comboBox.Items.Add(optionIdentify);
      if not VarIsNull(value) and not VarIsEmpty(value) then comboBox.ItemIndex := comboBox.Items.IndexOf(value)
      else comboBox.ItemIndex := 0;

      {}
      Inc(insertIndex);
    end;
  end;

begin
  {Read Options}
  if not (FDevilBoxControl.ReadOptions) then Exit;

  {Output Modules}
  outputModules;

  {Output Options}
  outputOptions;

  {}
  Result := True;
end;

function TFMain.ReadDomains: Boolean;
var
  domain: string;
begin
  if FDevilBoxControl.ReadDomains then
  begin
    {Output Domains}
    lb_domains.Clear;
    for domain in FDevilBoxControl.Domains do lb_domains.Items.Add(domain);
  end;

  Result := (FDevilBoxControl.Domains.Count > 0);
end;

end.
