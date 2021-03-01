unit ubufferedreader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type

  { TBufferedReader }

  TBufferedReader = class
  protected
    FUnderlying:  TStream;
    FBuf:         array of Byte;
    FBufCapacity: LongInt;
    FBufSize:     LongInt;
    FBufOffset:   LongInt;
  public
    constructor Create(Underlying: TStream);
    destructor Destroy; override;

    function Read(out Buf; n: LongInt): LongInt;
    function ReadLine: String;
    procedure BlockRead(out Buf; n: LongInt);

    property Underlying: TStream read FUnderlying;
  end;

  { TTeeStream }

  TTeeStream = class(TStream)
  protected
    FSource: TStream;
    FCC:     TStream;
  public
    constructor Create(Source, CC: TStream);
    function Read(var Buffer; Count: Longint): Longint; override;
  end;

implementation

{ TTeeStream }

constructor TTeeStream.Create(Source, CC: TStream);
begin
  inherited Create;
  FSource := Source;
  FCC     := CC;
end;

function TTeeStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FSource.Read(Buffer, Count);
  if Result > 0 then
    FCC.WriteBuffer(Buffer, Result);
end;

{ TBufferedReader }

constructor TBufferedReader.Create(Underlying: TStream);
begin
  FUnderlying  := Underlying;
  FBufCapacity := 1024;
  FBufOffset   := 0;
  FBufSize     := 0;
  SetLength(FBuf, FBufCapacity);
end;

destructor TBufferedReader.Destroy;
begin
  inherited Destroy;
end;

function TBufferedReader.Read(out Buf; n: LongInt): LongInt;
var
  Available: LongInt;
begin
  Available := FBufSize - FBufOffset;
  if Available > 0 then
  begin
    if Available < n then
      n := Available;
    Move(FBuf[FBufOffset], Buf, n);
    Inc(FBufOffset, n);
    Result := n;
  end
  else
  begin
    Result := Underlying.Read(Buf, n);
  end;
end;

function TBufferedReader.ReadLine: String;
var
  idx, n, o: LongInt;

  function ScanAhead: LongInt;
  var
    i: integer;
  begin
    for i := FBufOffset to FBufSize - 1 do
      if (Chr(FBuf[i]) = #13) and ((i = FBufSize - 1) or (Chr(FBuf[i+1]) = #10)) then
      begin
        Result := i;
        exit;
      end;
    Result := FBufSize;
  end;

begin
  Result := '';
  o := 0;

  while True do
  begin
    idx := ScanAhead;
    n := idx - FBufOffset;

    if n > 0 then
    begin
      SetLength(Result, o + n);
      Move(FBuf[FBufOffset], Result[o + 1], n);
      inc(o, n);
    end;

    FBufOffset := idx;

    // \r\n was found somewhere in the middle of the buffer
    if idx < FBufSize - 1 then
    begin
      inc(FBufOffset, 2);
      Exit;
    end
    // \r was found at the end of the buffer. Could be linebreak or not.
    else if idx = FBufSize - 1 then
    begin
      FBuf[0] := FBuf[idx];
      FBufOffset := 0;
      FBufSize := 1 + Underlying.Read(FBuf[1], FBufCapacity - 1);
    end
    // No (potential) linebreak was found in the buffer.
    else {if idx = FBufSize then}
    begin
      FBufOffset := 0;
      FBufSize := Underlying.Read(FBuf[0], FBufCapacity);
    end;

    if FBufSize = 0 then
      Exit;
  end;

end;

procedure TBufferedReader.BlockRead(out Buf; n: LongInt);
var
  Total, Delta: LongInt;
  Ptr: PByte;
begin
  assert(n > 0, 'Must read at least one byte');
  Ptr := PByte(@Buf);
  Total := 0;
  while Total < n do
  begin
    Delta := Read(Ptr^, n - Total);
    if Delta = 0 then
      raise EStreamError.Create('Stream abruptly ended');
    Inc(Total, Delta);
    Inc(Ptr, Delta);
  end;
end;

end.

