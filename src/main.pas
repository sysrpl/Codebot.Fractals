unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Menus, FractalTools, Codebot.System, Codebot.Graphics, Codebot.Graphics.Types,
  Codebot.Text.Json;

{ TFractalForm }

type
  TFractalForm = class(TForm)
    GoButton: TButton;
    CoresEdit: TEdit;
    CoresLabel: TLabel;
    StatusPanel: TPanel;
    ZoomEdit: TEdit;
    XEdit: TEdit;
    YEdit: TEdit;
    ZoomLabel: TLabel;
    PaintBox: TPaintBox;
    XLabel: TLabel;
    YLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormPaint(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
      {%H-}Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxPaint(Sender: TObject);
  private
    FPrior, FTime: Double;
    FZoom, FX, FY: Double;
    FMouse: TPoint;
    FCores: Integer;
    procedure UpdateStatus;
  public

  end;

var
  FractalForm: TFractalForm;

implementation

{$R *.lfm}

const
  Margin = 8;

procedure PackControls(C: array of TControl);
var
  I, M, X: Integer;
begin
  if Length(C) < 2 then
    Exit;
  M := C[0].Top + C[0].Height div 2;
  X := C[0].Left + C[0].Width + Margin;
  for I := 1 to Length(C) - 1 do
  begin
    C[I].Left := X;
    X := X + C[I].Width + Margin;
    C[I].Top := M - C[I].Height div 2;
  end;
end;

{ TFractalForm }

procedure TFractalForm.FormCreate(Sender: TObject);
var
  N: TJsonNode;
  S: string;
  W, H: Integer;
begin
  FZoom := 1;
  FX := -0.5;
  FCores := 1;
  W := PaintBox.Width;
  H := PaintBox.Height;
  S := ConfigAppFile(False, True);
  if FileExists(S) then
  begin
    N := TJsonNode.Create;
    N.LoadFromFile(S);
    try
      if N.Find('zoom') <> nil then
        FZoom := N.Find('zoom').AsNumber;
      if N.Find('x') <> nil then
        FX := N.Find('x').AsNumber;
      if N.Find('y') <> nil then
        FY := N.Find('y').AsNumber;
      if N.Find('cores') <> nil then
        FCores := Round(N.Find('cores').AsNumber);
      if N.Find('width') <> nil then
        W := Round(N.Find('width').AsNumber);
      if N.Find('height') <> nil then
        H := Round(N.Find('height').AsNumber);
    except
    end;
  end;
  if FZoom < 0 then
    FZoom := 1;
  if FCores < 1 then
    FCores := 1
  else if FCores > 16 then
    FCores := 16;
  if W < 400 then
    W := 400
  else if W > 1500 then
    W := 1500;
  if H < 300 then
    W := 300
  else if W > 900 then
    W := 900;
  PaintBox.Width := W;
  PaintBox.Height := H;
  StatusPanel.Left := PaintBox.Left;
  StatusPanel.Width := W;
  StatusPanel.Top := PaintBox.Top + H + 4;
  ZoomEdit.Text := FloatToStr(FZoom);
  XEdit.Text := FloatToStr(FX);
  YEdit.Text := FloatToStr(FY);
  CoresEdit.Text := IntToStr(FCores);
  ClientWidth := PaintBox.Width + PaintBox.Left * 2;
  ClientHeight := StatusPanel.Top + StatusPanel.Height + StatusPanel.Left;
  PaintBox.Anchors := [akLeft, akTop, akRight, akBottom];
  StatusPanel.Anchors := [akLeft, akRight, akBottom];
end;

procedure TFractalForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  N: TJsonNode;
  S: string;
begin
  S := ConfigAppFile(False, True);
  N := TJsonNode.Create;
  try
    N.Add('zoom').AsNumber := FZoom;
    N.Add('x').AsNumber := FX;
    N.Add('y').AsNumber := FY;
    N.Add('cores').AsNumber := FCores;
    N.Add('width').AsNumber := PaintBox.Width;
    N.Add('height').AsNumber := PaintBox.Height;
  finally
    N.SaveToFile(S);
  end;
  N.Free;
end;

procedure TFractalForm.UpdateStatus;
var
  PX, PY, Z: Double;
  Speed, Coord: string;
  I, J: Integer;
begin
  I := Round(FTime * 1000);
  J := Round(FPrior * 1000);
  Speed := 'Render time ' + IntToStr(I) + 'ms';
  if J > 0 then
    if I < J then
    begin
      I := Round(J / I * 100) - 100;
      Speed := Speed + ' ' + IntToStr(I) + '% faster than prior time of ' + IntToStr(J) + 'ms';
    end
    else if J < I then
    begin
      I := Round(I / J * 100) - 100;
      Speed := Speed + ' ' + IntToStr(I) + '% slower than prior time of ' + IntToStr(J) + 'ms';
    end
    else
      Speed := Speed + ' the same as previous time';
  Z := FZoom;
  I := 4;
  while Z > 10 do
  begin
    Inc(I);
    Z := Z / 10;
  end;
  Coord := '  X: %.' + IntToStr(I) + 'f, Y: %.' + IntToStr(I) + 'f';
  PX := FMouse.X;
  PY := FMouse.Y;
  PanMandelbrot(PaintBox.ClientRect, FZoom, PX, PY);
  Coord := Format(Coord, [FX + PX, FY + PY]);
  StatusPanel.Caption := '  ' + Speed + '. ' + Coord;
end;

procedure TFractalForm.FormPaint(Sender: TObject);
begin
  OnPaint := nil;
  PackControls([ZoomLabel, ZoomEdit, XLabel, XEdit, YLabel, YEdit, CoresLabel,
    CoresEdit, GoButton]);
  GoButton.Left := ClientWidth - GoButton.Width - Margin;
  GoButton.Anchors := [akTop, akRight];
  StatusPanel.SetFocus;
end;

procedure TFractalForm.GoButtonClick(Sender: TObject);
begin
  StatusPanel.SetFocus;
  FZoom := StrToFloatDef(Trim(ZoomEdit.Text), FZoom);
  ZoomEdit.Text := FloatToStr(FZoom);
  FX := StrToFloatDef(Trim(XEdit.Text), FX);
  XEdit.Text := FloatToStr(FX);
  FY := StrToFloatDef(Trim(YEdit.Text), FY);
  YEdit.Text := FloatToStr(FY);
  FCores := StrToIntDef(Trim(CoresEdit.Text), FCores);
  if FCores < 1 then
    FCores := 1
  else if FCores > 16 then
    FCores := 16;
  CoresEdit.Text := IntToStr(FCores);
  PaintBox.Invalidate;
end;

procedure TFractalForm.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  FMouse.X := X;
  FMouse.Y := Y;
  UpdateStatus;
end;

procedure TFractalForm.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  PX, PY: Double;
begin
  PX := X;
  PY := Y;
  PanMandelbrot(PaintBox.ClientRect, FZoom, PX, PY);
  FX := FX + PX;
  FY := FY + PY;
  if Button = mbLeft then
    FZoom := FZoom * 2
  else if Button = mbRight then
    FZoom := FZoom / 2;
  if FZoom < 1 then
    FZoom := 1;
  ZoomEdit.Text := FloatToStr(FZoom);
  XEdit.Text := FloatToStr(FX);
  YEdit.Text := FloatToStr(FY);
  Mouse.CursorPos := PaintBox.ClientToScreen(Point(PaintBox.Width div 2, PaintBox.Height div 2));
  GoButton.Click;
end;

procedure TFractalForm.PaintBoxPaint(Sender: TObject);
var
  S: ISurface;
begin
  S := NewSurface(PaintBox.Canvas);
  FPrior := FTime;
  FTime := TimeQuery;
  DrawMandelbrotCore(FCores, S, PaintBox.ClientRect, FX, FY, FZoom);
  FTime := TimeQuery - FTime;
  UpdateStatus;
end;

end.

