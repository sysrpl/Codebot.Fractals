unit FractalTools;

{$mode delphi}

interface

uses
  Classes,
  Codebot.System,
  Codebot.Graphics,
  Codebot.Graphics.Types;

procedure DrawMandelbrot(S: ISurface; R: TRectI; X, Y, Z: Double);
procedure DrawMandelbrotCore(NumCores: Integer; S: ISurface; R: TRectI; X, Y, Z: Double);
procedure PanMandelbrot(R: TRectI; Z: Double; var X, Y: Double);

implementation

function LogN(N, X: Double): Double;
begin
  Result := ln(X) / ln(N);
end;

function MandelbrotSetColor(Zx, Zy, Cx, Cy: Double; Itter: Integer): TColorB;
const
  LogBounds = 0.30102999566;
var
  Zxx, Zyy, H: Double;
  I: Integer;
begin
  Zxx := Zx * Zx;
  Zyy := Zy * Zy;
  I := 0;
  while (Zxx + Zyy < 4) and (I < Itter) do
  begin
    Zy := 2 * Zx * Zy + Cy;
    Zx := Zxx - Zyy + Cx;
    Zxx := Zx * Zx;
    Zyy := Zy * Zy;
    Inc(I);
  end;
  if I = Itter then
    Result := 0
  else
  begin
    H := I + 1 + LogN(Sqrt(Zxx + Zyy), 2) / LogBounds;
    Result := HueToColor(H / 500);
  end;
end;

procedure DrawMandelbrotProc(Pixel: PPixel; Width, Height, CoreIndex, CoreCount: Integer; X, Y, Z: Double);
const
  Scale = 200;
  Itter = 500;
var
  W, H: Integer;
  StepS, StepV, T, U, V: Double;
begin
  StepS := (1 - Width / 2) / Scale / Z - (-Width / 2) / Scale / Z;
  StepV := (1 - Height / 2) / Scale / -Z - (-Height / 2) / Scale / -Z;
  T := -Width / 2 / Scale / Z + X;
  U := T;
  V := Height / 2 / Scale / Z + Y;
  for H := 0 to Height - 1 do
  begin
    if H mod CoreCount = CoreIndex then
      for W := 0 to Width - 1  do
      begin
        Pixel^ := MandelbrotSetColor(0, 0, U, V, Itter);
        U := U + StepS;
        Inc(Pixel);
      end
      else
        Inc(Pixel, Width);
    U := T;
    V := V + StepV;
  end;
end;

type
  TMandelbrotCore = class(TThread)
  private
    FPixels: PPixel;
    FCoreCount: Integer;
    FCoreIndex: Integer;
    FWidth: Integer;
    FHeight: Integer;
    FX, FY, FZ: Double;
  protected
    procedure Execute; override;
  public
    constructor Create(Pixels: PPixel; CoreCount, CoreIndex, Width, Height: Integer;
      X, Y, Z: Double);
  end;

constructor TMandelbrotCore.Create(Pixels: PPixel; CoreCount, CoreIndex, Width, Height: Integer;
  X, Y, Z: Double);
begin
  FPixels := Pixels;
  FCoreCount := CoreCount;
  FCoreIndex := CoreIndex;
  FWidth := Width;
  FHeight := Height;
  FX := X;
  FY := Y;
  FZ := Z;
  inherited Create(False);
end;

procedure TMandelbrotCore.Execute;
begin
  DrawMandelbrotProc(FPixels, FWidth, FHeight, FCoreIndex, FCoreCount, FX, FY, FZ);
end;

procedure DrawMandelbrot(S: ISurface; R: TRectI; X, Y, Z: Double);
var
  B: IBitmap;
begin
  B := NewBitmap(R.Width, R.Height);
  DrawMandelbrotProc(B.Pixels, R.Width, R.Height, 0, 1, X, Y, Z);
  B.Surface.CopyTo(R, S, R);
end;

procedure DrawMandelbrotCore(NumCores: Integer; S: ISurface; R: TRectI; X, Y, Z: Double);
var
  Cores: TArrayList<TMandelbrotCore>;
  B: IBitmap;
  P: PPixel;
  I: Integer;
begin
  if NumCores < 1 then
    NumCores := 1;
  if NumCores > 16 then
    NumCores := 16;
  B := NewBitmap(R.Width, R.Height);
  P := B.Pixels;
  Cores.Length := NumCores;
  for I := 0 to NumCores - 1 do
    Cores[I] := TMandelbrotCore.Create(P, NumCores, I, R.Width, R.Height, X, Y, Z);
  for I := 0 to NumCores - 1 do
  begin
    Cores[I].WaitFor;
    Cores[I].Free;
  end;
  B.Surface.CopyTo(R, S, R);
end;

procedure PanMandelbrot(R: TRectI; Z: Double; var X, Y: Double);
begin
  X :=  (X - R.Width / 2) / 200 / Z;
  Y :=  (Y - R.Height / 2) / 200 / -Z;
end;

end.

