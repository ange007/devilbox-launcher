unit mainF;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Generics.Collections, System.Math, System.IniFiles,

  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.ListBox, FMX.TabControl,
  FMX.Edit, FMX.Layouts,

  DevilBoxControl, FMX.Objects, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo;

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
    btn_domains_open_dir: TButton;
    btn_open_panel: TButton;
    ti_debug: TTabItem;
    m_debug: TMemo;
    btn_update: TButton;
    cb_remove_images: TCheckBox;
    btn_domains_reload: TButton;
    pnl_options: TPanel;
    {}
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
    procedure lb_domainsDblClick(Sender: TObject);
    procedure e_docker_pathDblClick(Sender: TObject);
    {}
    procedure btn_closeClick(Sender: TObject);
    procedure btn_save_buildClick(Sender: TObject);
    procedure btn_stopClick(Sender: TObject);
    procedure btn_domains_open_dirClick(Sender: TObject);
    procedure btn_open_panelClick(Sender: TObject);
    procedure btn_updateClick(Sender: TObject);
    procedure btn_domains_reloadClick(Sender: TObject);
  private
    FDevilBoxControl: TDevilBoxControl;
    FIsInit: Boolean;

    function Init: Boolean;

    procedure ReadOptions;
    procedure ReadDomains;
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

procedure TFMain.btn_open_panelClick(Sender: TObject);
begin
  FDevilBoxControl.RunCommand('open', 'http://localhost', '');
end;

procedure TFMain.btn_saveClick(Sender: TObject);
begin
  if Init then FDevilBoxControl.Build;
end;

procedure TFMain.btn_save_buildClick(Sender: TObject);
begin
  if Init then
  begin
    FDevilBoxControl.Build;
    FDevilBoxControl.Run(cb_remove_images.IsChecked);
  end;
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

procedure TFMain.lb_domainsDblClick(Sender: TObject);
begin
  if lb_domains.ItemIndex < 0 then Exit;

  FDevilBoxControl.OpenDomainDir(lb_domains.Selected.Text);
end;

{

}

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
begin
  {Save options}
  with TIniFile.Create('./launcher.ini') do
  begin
    WriteString('options', 'work_path', e_work_path.Text);
    WriteString('options', 'docker_path', e_docker_path.Text);
    WriteBool('options', 'remove_images', cb_remove_images.IsChecked);

    Free;
  end;

  {}
  FreeAndNil(FDevilBoxControl);
end;

procedure TFMain.FormCreate(Sender: TObject);
begin
  {Load options}
  with TIniFile.Create('./launcher.ini') do
  begin
    e_work_path.Text := ReadString('options', 'work_path', '');
    e_docker_path.Text := ReadString('options', 'docker_path', '');
    cb_remove_images.IsChecked := ReadBool('options', 'remove_images', True);

    Free;
  end;

  {}
  tc_main.ActiveTab := ti_domains;

  {Init}
  Init;
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
  end;

  {}
  FDevilBoxControl.OnStopped := procedure
  begin
    btn_stop.Visible := False;
    btn_open_panel.Visible := False;
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

procedure TFMain.ReadOptions;

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
  FDevilBoxControl.ReadOptions;

  {Output Modules}
  outputModules;
end;

procedure TFMain.ReadDomains;
var
  domain: string;
begin
  if FDevilBoxControl.ReadDomains then
  begin
    {Output Domains}
    lb_domains.Clear;
    for domain in FDevilBoxControl.Domains do lb_domains.Items.Add(domain);
  end;
end;

end.
