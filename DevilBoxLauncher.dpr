program DevilBoxLauncher;

uses
  System.StartUpCopy,
  FMX.Forms,
  mainF in 'src\forms\mainF.pas' {FMain},
  DevilBoxControl in 'src\modules\DevilBoxControl.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFMain, FMain);
  Application.Run;
end.
