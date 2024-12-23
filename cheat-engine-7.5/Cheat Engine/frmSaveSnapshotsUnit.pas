unit frmSaveSnapshotsUnit;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Math,
  LuaCanvas, FPImage, FPCanvas, FPImgCanv, FPReadPNG, FPWritePNG, betterControls;

const
  TRANSPARENT_COLOR = $FF00FF;
  MAX_LOADED_SNAPSHOTS = 64;
  SNAPSHOT_EXTENSION = '.ce3dsnapshot';

resourcestring
  rsSSAreYouSureYouWishToThrowAwayTheseSnapshots = 'Are you sure you wish to throw away these snapshots?';

type
  TSnapshot = class
  private
    FFilename: string;
    FPic: TBitmap;
    FSelected: Boolean;
    FXPos: Integer;
    FWidth: Integer;
  public
    constructor Create(const Filename: string);
    destructor Destroy; override;

    procedure Load;
    procedure Unload;

    property Filename: string read FFilename;
    property Pic: TBitmap read FPic;
    property Selected: Boolean read FSelected write FSelected;
    property XPos: Integer read FXPos write FXPos;
    property Width: Integer read FWidth write FWidth;
  end;

  TSnapshots = class
  private
    FList: TList;
    FLoadedCount: Integer;

    procedure Cleanup(index: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    function Add(const Filename: string): TSnapshot;
    procedure Clear;
    function GetItem(Index: Integer): TSnapshot;
    procedure SelectAll;
    procedure DeselectAll;

    property LoadedCount: Integer read FLoadedCount;
    property Items[Index: Integer]: TSnapshot read GetItem; default;
  end;

  { TfrmSaveSnapshots }

  TfrmSaveSnapshots = class(TForm)
    btnSave: TButton;
    btnDone: TButton;
    btnCombinedSelect: TButton;
    Label1: TLabel;
    lblDeselectAll: TLabel;
    lblSelectAll: TLabel;
    PaintBox1: TPaintBox;
    Panel1: TPanel;
    Panel2: TPanel;
    SaveDialog1: TSaveDialog;
    ScrollBar1: TScrollBar;

    procedure btnSaveClick(Sender: TObject);
    procedure btnDoneClick(Sender: TObject);
    //procedure btnCombinedSelectClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lblDeselectAllClick(Sender: TObject);
    procedure lblSelectAllClick(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1Paint(Sender: TObject);
    procedure Panel2Resize(Sender: TObject);
    procedure ScrollBar1Change(Sender: TObject);
  private
    Snapshots: TSnapshots;
    FSaved: TStringList;

    procedure InitializeSnapshots(const Path: string; Max: Integer);
  public
    property Saved: TStringList read FSaved;
  end;

var
  frmSaveSnapshots: TfrmSaveSnapshots;

implementation

{$R *.lfm}

{ TSnapshot }

constructor TSnapshot.Create(const Filename: string);
begin
  FFilename := Filename;
  FPic := nil;
  FSelected := False;
end;

destructor TSnapshot.Destroy;
begin
  if Assigned(FPic) then
    FreeAndNil(FPic);
  inherited Destroy;
end;

procedure TSnapshot.Load;
var
  S: TFileStream;
  PictureSize, Format: Integer;
  FPImage: TFPMemoryImage;
  FPReader: TFPReaderPNG;
  Canvas: TFPCustomCanvas;
begin
  if Assigned(FPic) then Exit;

  S := TFileStream.Create(FFilename, fmOpenRead);
  try
    S.Position := 4;
    S.ReadBuffer(Format, SizeOf(Format));
    S.ReadBuffer(PictureSize, SizeOf(PictureSize));

    if Format = 0 then
    begin
      FPic := TBitmap.Create;
      FPic.LoadFromStream(S, PictureSize);
    end
    else if Format = 3 then
    begin
      FPImage := TFPMemoryImage.Create(0, 0);
      FPReader := TFPReaderPNG.Create;
      try
        FPImage.LoadFromStream(S, FPReader);
        Canvas := TFPImageCanvas.Create(FPImage);

        FPic := TBitmap.Create;
        FPic.Width := FPImage.Width;
        FPic.Height := FPImage.Height;
        TFPCustomCanvas(FPic.Canvas).CopyRect(0, 0, Canvas, Rect(0, 0, FPImage.Width, FPImage.Height));
      finally
        Canvas.Free;
        FPReader.Free;
        FPImage.Free;
      end;
    end;
  finally
    S.Free;
  end;
end;

procedure TSnapshot.Unload;
begin
  if Assigned(FPic) then
    FreeAndNil(FPic);
end;

{ TSnapshots }

constructor TSnapshots.Create;
begin
  FList := TList.Create;
  FLoadedCount := 0;
end;

destructor TSnapshots.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TSnapshots.Cleanup(index: Integer);
var
  I: Integer;
begin
  if FLoadedCount > MAX_LOADED_SNAPSHOTS then
  begin
    for I := Index - 16 downto 0 do
      if Items[I].Pic <> nil then
      begin
        Items[I].Unload;
        Dec(FLoadedCount);
      end;

    for I := Index + 48 to FList.Count - 1 do
      if Items[I].Pic <> nil then
      begin
        Items[I].Unload;
        Dec(FLoadedCount);
      end;
  end;
end;

function TSnapshots.Add(const Filename: string): TSnapshot;
var
  Snapshot: TSnapshot;
begin
  Snapshot := TSnapshot.Create(Filename);
  FList.Add(Snapshot);
  Result := Snapshot;
end;

procedure TSnapshots.Clear;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    TSnapshot(FList[I]).Free;
  FList.Clear;
end;

function TSnapshots.GetItem(Index: Integer): TSnapshot;
begin
  Result := TSnapshot(FList[Index]);
end;

procedure TSnapshots.SelectAll;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    Items[I].Selected := True;
end;

procedure TSnapshots.DeselectAll;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    Items[I].Selected := False;
end;

{ TfrmSaveSnapshots }

procedure TfrmSaveSnapshots.InitializeSnapshots(const Path: string; Max: Integer);
var
  I: Integer;
begin
  ScrollBar1.Position := 0;
  ScrollBar1.Max := Max - 1;

  Snapshots.Clear;
  for I := 0 to Max - 1 do
    Snapshots.Add(Format('%ssnapshot%d%s', [Path, I + 1, SNAPSHOT_EXTENSION]));
end;

procedure TfrmSaveSnapshots.btnSaveClick(Sender: TObject);
var
  I, Count: Integer;
  FilePath: string;
begin
  if SaveDialog1.Execute then
  begin
    FSaved.Clear;
    Count := 1;
    for I := 0 to Snapshots.FList.Count - 1 do
      if Snapshots[I].Selected then
      begin
        FilePath := ChangeFileExt(SaveDialog1.FileName, Format('(%d)%s', [Count, ExtractFileExt(SaveDialog1.FileName)]));
        //CopyFile(Snapshots[I].Filename, FilePath, True);
        FSaved.Add(FilePath);
        Inc(Count);
      end;

    Snapshots.DeselectAll;
    PaintBox1.Repaint;
  end;
end;

procedure TfrmSaveSnapshots.btnDoneClick(Sender: TObject);
begin
  if FSaved.Count > 0 then
    btnSaveClick(Sender);
  Close;
end;

procedure TfrmSaveSnapshots.lblDeselectAllClick(Sender: TObject);
begin
  Snapshots.DeselectAll;
  PaintBox1.Repaint;
end;

procedure TfrmSaveSnapshots.lblSelectAllClick(Sender: TObject);
begin
  Snapshots.SelectAll;
  PaintBox1.Repaint;
end;

procedure TfrmSaveSnapshots.PaintBox1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  for I := ScrollBar1.Position to Snapshots.FList.Count - 1 do
    if InRange(X, Snapshots[I].XPos, Snapshots[I].XPos + Snapshots[I].Width) then
    begin
      Snapshots[I].Selected := not Snapshots[I].Selected;
      Break;
    end;
  PaintBox1.Repaint;
end;

procedure TfrmSaveSnapshots.PaintBox1Paint(Sender: TObject);
var
  I, XPos, CurrentWidth, H: Integer;
  AspectRatio: Single;
begin
  PaintBox1.Canvas.Clear;
  XPos := 0;
  H := PaintBox1.Height;

  for I := ScrollBar1.Position to Snapshots.FList.Count - 1 do
  begin
    Snapshots[I].Load;
    AspectRatio := Snapshots[I].Pic.Width / Snapshots[I].Pic.Height;
    CurrentWidth := Ceil(H * AspectRatio);

    PaintBox1.Canvas.CopyRect(Rect(XPos, 0, XPos + CurrentWidth, H),
      Snapshots[I].Pic.Canvas, Rect(0, 0, Snapshots[I].Pic.Width, Snapshots[I].Pic.Height));

    Snapshots[I].XPos := XPos;
    Snapshots[I].Width := CurrentWidth;

    if Snapshots[I].Selected then
    begin
      PaintBox1.Canvas.Pen.Width := 3;
      PaintBox1.Canvas.Pen.Color := clAqua;
      PaintBox1.Canvas.Brush.Style := bsClear;
      PaintBox1.Canvas.Rectangle(Rect(XPos, 0, XPos + CurrentWidth, H));
      PaintBox1.Canvas.Brush.Style := bsSolid;
    end;

    Inc(XPos, CurrentWidth + 1);
    if XPos > PaintBox1.Width then
      Exit;
  end;
end;

procedure TfrmSaveSnapshots.Panel2Resize(Sender: TObject);
begin
  btnSave.Left := Panel2.Width div 2 - btnSave.Width div 2;
  btnDone.Left := Panel2.Width div 2 - btnDone.Width div 2;
end;

procedure TfrmSaveSnapshots.ScrollBar1Change(Sender: TObject);
begin
  PaintBox1.Repaint;
end;

procedure TfrmSaveSnapshots.FormCreate(Sender: TObject);
begin
  Snapshots := TSnapshots.Create;
  FSaved := TStringList.Create;
end;

procedure TfrmSaveSnapshots.FormDestroy(Sender: TObject);
begin
  Snapshots.Free;
  FSaved.Free;
end;

procedure TfrmSaveSnapshots.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if (FSaved.Count > 0) or
    (MessageDlg(rsSSAreYouSureYouWishToThrowAwayTheseSnapshots, mtConfirmation, [mbYes, mbNo], 0) = mrYes) then
    CanClose := True
  else
    CanClose := False;
end;

end.

