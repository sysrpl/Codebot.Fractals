program fractals;

{$mode objfpc}{$H+}

uses
  Codebot.System,
  Interfaces, // this includes the LCL widgetset
  Forms, Main, FractalTools
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFractalForm, FractalForm);
  Application.Run;
end.

