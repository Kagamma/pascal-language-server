// Pascal Language Server
// Copyright 2020 Arjan Adriaanse
//           2021 Philip Zander
//           2022 kagamma

// This file is part of Pascal Language Server.

// Pascal Language Server is free software: you can redistribute it
// and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation, either version 3 of
// the License, or (at your option) any later version.

// Pascal Language Server is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Pascal Language Server.  If not, see
// <https://www.gnu.org/licenses/>.

program pasls;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, iostream, streamex, udebug, ubufferedreader, jsonstream,
  upackages, ujsonrpc, uinitialize, utextdocument, uutils;

procedure SendError(
  Rpc: TRpcPeer; Id: TRpcId; Code: Integer; const Msg: string
);
var
  Response: TRpcResponse;
begin
  Response := nil;
  try
    Response := TRpcResponse.CreateError(Id, Code, Msg);
    Rpc.Send(Response);
  finally
    FreeAndNil(Response);
  end;
end;

procedure Dispatch(Rpc: TRpcPeer; Request: TRpcRequest);
begin
  case Request.Method of
    'initialize':
      Initialize(Rpc, Request);
    'initialized',
    'shutdown',
    'textDocument/didOpen':
      TextDocument_DidOpen(Rpc, Request);
    'textDocument/didChange':
      TextDocument_DidChange(Rpc, Request);
    'textDocument/didClose',
    'textDocument/completion':
      TextDocument_Completion(Rpc, Request);
    'textDocument/signatureHelp':
      TextDocument_SignatureHelp(Rpc, Request);
    'textDocument/declaration':
      TextDocument_Declaration(Rpc, Request);
    'textDocument/definition':
      TextDocument_Definition(Rpc, Request);
    'workspace/didChangeConfiguration':
      TextDocument_DidChangeConfiguration(Rpc, Request);
    'exit':
      begin
        // Do nothing
      end;
    '$/cancelRequest':
      begin
        // Do nothing
      end;
    else
      raise ERpcError.CreateFmt(
        jsrpcMethodNotFound, 'Method not found: %s', [Request.Method]
      );
  end;
end;

procedure Main(Rpc: TRpcPeer);
var
  Request: TRpcRequest;
begin
  while True do
  begin
    Request := nil;
    try
      Request := Rpc.Receive;

      if Request = nil then
      begin
        DebugLog('** End of stream, exiting **');
        exit;
      end;

      try
        Dispatch(Rpc, Request);
      except
        on E: ERpcError do
          SendError(Rpc, Request.Id, E.Code, E.Message);
      end;
    finally
      FreeAndNil(Request);
    end;
  end;
end;


var
  InputStream:    TStream;
  OutputStream:   TStream;
  DebugStream:    TStream;
  Transcript:     TStream;
  Tee:            TStream;

  RpcPeer:        TRpcPeer;

  TranscriptPath: string  = '';
  LogPath:        string  = '';
  SaveReplay:     Boolean = false;
  LoadReplay:     Boolean = false;

procedure PrintUsage;
begin
  // TODO: Implement
end;

procedure ParseOptions;
var
  i: integer;
begin
  i := 1;
  while i <= ParamCount do
  begin
    if (ParamStr(i) = '--save-log') and (i < ParamCount) then
    begin
      LogPath        := ParamStr(i + 1);
      Inc(i);
    end
    else if (ParamStr(i) = '--save-replay') and (i < ParamCount) then
    begin
      SaveReplay     := true;
      TranscriptPath := ParamStr(i + 1);
      Inc(i);
    end
    else if (ParamStr(i) = '--replay') and (i < ParamCount) then
    begin
      LoadReplay     := true;
      TranscriptPath := ParamStr(i + 1);
      Inc(i);
    end
    else
    begin
      PrintUsage;
      break;
    end;
    Inc(i);
  end;
end;

begin
  {$ifdef WINDOWS}
  SetTextLineEnding(Input, #13#10);
  SetTextLineEnding(Output, #13#10);
  {$endif}
  InputStream    := nil;
  OutputStream   := nil;
  DebugStream    := nil;
  Transcript     := nil;
  Tee            := nil;
  RpcPeer        := nil;

  ParseOptions;

  if LogPath <> '' then
    try
      if LogPath = '-' then
        DebugStream := TIOStream.Create(iosError)
      else
        DebugStream := TFileStream.Create(LogPath, fmCreate);
    except
      DebugStream := TIOStream.Create(iosError);
    end;

  InitLog(DebugStream);

  if LoadReplay and SaveReplay then
  begin
    DebugLog('You specified both --save-replay and --replay. Ignoring.');
    LoadReplay := false;
    SaveReplay := false;
  end;

  try
    InputStream  := TIOStream.Create(iosInput);
    OutputStream := TIOStream.Create(iosOutput);

    if SaveReplay then
    begin
      try
        Transcript := TFileStream.Create(TranscriptPath, fmCreate);
      except
        DebugLog(
          'Could not create replay file "%s".',
          [TranscriptPath]
        );
        FreeAndNil(Transcript);
      end;
      Tee          := TTeeStream.Create(InputStream, Transcript);
      RpcPeer      := TRpcPeer.Create(Tee, OutputStream);
    end
    else if LoadReplay then
    begin
      InputStream  := TFileStream.Create(TranscriptPath, fmOpenRead);
      RpcPeer      := TRpcPeer.Create(InputStream, OutputStream);
    end
    else
    begin
      RpcPeer      := TRpcPeer.Create(InputStream, OutputStream);
    end;

    try
      Main(RpcPeer);
    except
      on E: Exception do
        DebugLog('FATAL EXCEPTION: ' + E.Message);
    end;
  finally
    FreeAndNil(InputStream);
    FreeAndNil(OutputStream);
    FreeAndNil(DebugStream);
    FreeAndNil(Transcript);
    FreeAndNil(Tee);
    FreeAndNil(RpcPeer);
  end;

end.
