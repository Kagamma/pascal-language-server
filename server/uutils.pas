// Pascal Language Server
// Copyright 2021 Philip Zander

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

unit uutils;

{$mode objfpc}{$H+}

interface

function MergePaths(Paths: array of string): string;
function GetConfigDirForApp(AppName, Vendor: string; Global: Boolean): string;

implementation

uses
  sysutils;

function MergePaths(Paths: array of string): string;
var
  i: Integer;
begin
  Result := '';
  for i := low(Paths) to high(Paths) do
  begin
    if (Result <> '') and (Paths[i] <> '') then
      Result := Result + ';' + Paths[i]
    else if (Result = '') and (Paths[i] <> '') then
      Result := Paths[i];
  end;
end;


// yuck
var
  _FakeAppName, _FakeVendorName: string;

function GetFakeAppName: string;
begin
  Result := _FakeAppName;
end;

function GetFakeVendorName: string;
begin
  Result := _FakeVendorName;
end;

function GetConfigDirForApp(AppName, Vendor: string; Global: Boolean): string;
var
  OldGetAppName:     TGetAppNameEvent;
  OldGetVendorName:  TGetVendorNameEvent;
begin
  _FakeAppName     := AppName;
  _FakeVendorName  := Vendor;
  OldGetAppName    := OnGetApplicationName;
  OldGetVendorName := OnGetVendorName;
  try
    OnGetApplicationName := @GetFakeAppName;
    OnGetVendorName      := @GetFakeVendorName;
    Result               := GetAppConfigDir(Global);
  finally
    OnGetApplicationName := OldGetAppName;
    OnGetVendorName      := OldGetVendorName;
  end;
end;

end.
