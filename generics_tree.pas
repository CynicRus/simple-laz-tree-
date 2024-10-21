unit generics_tree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TNodeAttachMode = (naAddChild, naInsert);

  generic TGenericNode<T> = class
  public
  type
    TCompareFunction = function(const A, B: specialize TGenericNode<T>): integer of
    object;
    TNodeProcedure = procedure(const Item: specialize TGenericNode<T>) of object;
  private
  type
    TNodeArray = array of specialize TGenericNode<T>;
  var
    FChildren: TNodeArray;
    FParent: specialize TGenericNode<T>;
    FData: T;
    FDeleting: boolean;
    function GetChild(Index: integer): specialize TGenericNode<T>; inline;
    function GetChildCount: integer; inline;
    function GetIndex: integer;
    function GetLevel: integer;
    procedure SetParent(const Value: specialize TGenericNode<T>);
    procedure Orphan;
    procedure Adopt(const Child: specialize TGenericNode<T>);
    procedure QuickSort(const CompareFunc: TCompareFunction; L, R: integer);
    procedure InternalAddChild(Child: specialize TGenericNode<T>);
    procedure InternalRemoveChild(Child: specialize TGenericNode<T>);
  public

    constructor Create(const AData: T); overload;
    destructor Destroy; override;

    procedure Delete;
    procedure DeleteChildren;
    function GetFirstChild: specialize TGenericNode<T>;
    function GetLastChild: specialize TGenericNode<T>;
    function GetNext: specialize TGenericNode<T>;
    function GetNextChild(Value: specialize TGenericNode<T>): specialize TGenericNode<T>;
    function GetNextSibling: specialize TGenericNode<T>;
    function GetPrev: specialize TGenericNode<T>;
    function GetPrevChild(Value: specialize TGenericNode<T>): specialize TGenericNode<T>;
    function GetPrevSibling: specialize TGenericNode<T>;
    function HasAsParent(Value: specialize TGenericNode<T>): boolean;
    function IndexOf(Value: specialize TGenericNode<T>): integer;
    function MoveTo(Destination: specialize TGenericNode<T>;
      Mode: TNodeAttachMode): specialize TGenericNode<T>;
    function AddChild(const AData: T): specialize TGenericNode<T>;
    procedure Clear; inline;
    function IsEmpty: boolean; inline;
    procedure ExchangeChildren(Index1, Index2: integer);
    procedure Traverse(const Proc: TNodeProcedure; Recursive: boolean = True);
    procedure Sort(const CompareFunc: TCompareFunction; Recursive: boolean = True);

    property Data: T read FData write FData;
    property Index: integer read GetIndex;
    property Level: integer read GetLevel;
    property Parent: specialize TGenericNode<T> read FParent write SetParent;
    property Children[AIndex: integer]: specialize TGenericNode<T> read GetChild;
      default;
    property ChildCount: integer read GetChildCount;
    property Deleting: boolean read FDeleting;
  end;

implementation

{ TGenericNode<T> }

function TGenericNode.GetChild(Index: integer): specialize TGenericNode<T>;
begin
  Result := FChildren[Index];
end;

function TGenericNode.GetChildCount: integer;
begin
  Result := Length(FChildren);
end;

function TGenericNode.GetIndex: integer;
var
  I: integer;
begin
  Result := -1;
  if FParent <> nil then
  begin
    for I := 0 to High(FParent.FChildren) do
    begin
      if FParent.FChildren[I] = Self then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;
end;

function TGenericNode.GetLevel: integer;
begin
  if FParent <> nil then
    Result := FParent.GetLevel + 1
  else
    Result := 0;
end;

procedure TGenericNode.SetParent(const Value: specialize TGenericNode<T>);
begin
  if FParent = Value then Exit;
  if FParent <> nil then FParent.InternalRemoveChild(Self);
  FParent := Value;
  if FParent <> nil then FParent.InternalAddChild(Self);
end;

procedure TGenericNode.InternalRemoveChild(Child: specialize TGenericNode<T>);
var
  Pos, LastIdx: integer;
begin
  Pos := IndexOf(Child);
  if Pos <> -1 then
  begin
    for LastIdx := Pos to High(FChildren) - 1 do
      FChildren[LastIdx] := FChildren[LastIdx + 1];

    SetLength(FChildren, Length(FChildren) - 1);
  end;
end;

procedure TGenericNode.InternalAddChild(Child: specialize TGenericNode<T>);
begin
  SetLength(FChildren, Length(FChildren) + 1);
  FChildren[High(FChildren)] := Child;
end;

procedure TGenericNode.Orphan;
begin
  if FParent <> nil then
  begin
    FParent.InternalRemoveChild(Self);
    FParent := nil;
  end;
end;

procedure TGenericNode.Adopt(const Child: specialize TGenericNode<T>);
begin
  if Child <> nil then
    Child.SetParent(Self);
end;

procedure TGenericNode.QuickSort(const CompareFunc: TCompareFunction; L, R: integer);
var
  I, J: integer;
  P, Temp: specialize TGenericNode<T>;
begin
  if Length(FChildren) = 0 then Exit;

  repeat
    I := L;
    J := R;
    P := FChildren[(L + R) div 2];
    repeat
      while CompareFunc(FChildren[I], P) < 0 do Inc(I);
      while CompareFunc(FChildren[J], P) > 0 do Dec(J);
      if I <= J then
      begin
        Temp := FChildren[I];
        FChildren[I] := FChildren[J];
        FChildren[J] := Temp;
        Inc(I);
        Dec(J);
      end;
    until I > J;

    if L < J then QuickSort(CompareFunc, L, J);
    L := I;
  until I >= R;
end;

constructor TGenericNode.Create(const AData: T);
begin
  FData := AData;
  SetLength(FChildren, 0);
  FParent := nil;
end;

destructor TGenericNode.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TGenericNode.Delete;
begin
  if FParent <> nil then
    FParent.InternalRemoveChild(Self);
  Free;
end;

procedure TGenericNode.DeleteChildren;
var
  Node: specialize TGenericNode<T>;
begin
  Node := GetLastChild;
  while Node <> nil do
  begin
    Node.Delete;
    Node := GetLastChild;
  end;
end;

function TGenericNode.GetFirstChild: specialize TGenericNode<T>;
begin
  if ChildCount > 0 then
    Result := FChildren[0]
  else
    Result := nil;
end;

function TGenericNode.GetLastChild: specialize TGenericNode<T>;
begin
  if ChildCount > 0 then
    Result := FChildren[High(FChildren)]
  else
    Result := nil;
end;

function TGenericNode.GetNext: specialize TGenericNode<T>;
var
  Sibling: specialize TGenericNode<T>;
begin
  Sibling := GetNextSibling;
  if Sibling <> nil then
    Result := Sibling
  else if Parent <> nil then
    Result := Parent.GetNext
  else
    Result := nil;
end;

function TGenericNode.GetNextChild(Value: specialize TGenericNode<T>):
specialize TGenericNode<T>;
var
  Idx: integer;
begin
  Idx := IndexOf(Value);
  if (Idx <> -1) and (Idx < High(FChildren)) then
    Result := FChildren[Idx + 1]
  else
    Result := nil;
end;

function TGenericNode.GetNextSibling: specialize TGenericNode<T>;
begin
  if Parent <> nil then
    Result := Parent.GetNextChild(Self)
  else
    Result := nil;
end;

function TGenericNode.GetPrev: specialize TGenericNode<T>;
var
  Sibling: specialize TGenericNode<T>;
begin
  Sibling := GetPrevSibling;
  if Sibling <> nil then
    Result := Sibling.GetLastChild
  else
    Result := Parent;
end;

function TGenericNode.GetPrevChild(Value: specialize TGenericNode<T>):
specialize TGenericNode<T>;
var
  Idx: integer;
begin
  Idx := IndexOf(Value);
  if Idx > 0 then
    Result := FChildren[Idx - 1]
  else
    Result := nil;
end;

function TGenericNode.GetPrevSibling: specialize TGenericNode<T>;
var
  Pos: integer;
begin
  Pos := GetIndex;
  if Pos > 0 then
    Result := Parent.FChildren[Pos - 1]
  else
    Result := nil;
end;

function TGenericNode.HasAsParent(Value: specialize TGenericNode<T>): boolean;
var
  Current: specialize TGenericNode<T>;
begin
  Result := False;
  Current := Self;
  while Current.FParent <> nil do
  begin
    if Current.FParent = Value then
    begin
      Result := True;
      Exit;
    end;
    Current := Current.FParent;
  end;
end;

function TGenericNode.IndexOf(Value: specialize TGenericNode<T>): integer;
var
  I: integer;
begin
  Result := -1;
  for I := 0 to High(FChildren) do
    if FChildren[I] = Value then
    begin
      Result := I;
      Break;
    end;
end;

function TGenericNode.MoveTo(Destination: specialize TGenericNode<T>;
  Mode: TNodeAttachMode): specialize TGenericNode<T>;

  procedure InsertItemInArray(var Arr: TNodeArray; const Index: integer;
  const Item: specialize TGenericNode<T>);
  var
    I: integer;
  begin
    SetLength(Arr, Length(Arr) + 1);
    for I := High(Arr) - 1 downto Index do
      Arr[I + 1] := Arr[I];
    Arr[Index] := Item;
  end;

var
  Idx: integer;
begin
  Orphan;
  case Mode of
    naAddChild: Destination.Adopt(Self);
    naInsert:
    begin
      Idx := Destination.GetIndex;
      if Destination.FParent <> nil then
      begin
        SetParent(Destination.FParent);
        InsertItemInArray(Destination.FParent.FChildren, Idx, Self);
      end;
    end;
  end;
  Result := Self;
end;

function TGenericNode.AddChild(const AData: T): specialize TGenericNode<T>;
begin
  Result := specialize TGenericNode<T>.Create(AData);
  Adopt(Result);
end;


procedure TGenericNode.Clear;
var
  I: integer;
begin
  for I := High(FChildren) downto 0 do
    FChildren[I].Free;
  SetLength(FChildren, 0);
end;

function TGenericNode.IsEmpty: boolean;
begin
  Result := Length(FChildren) = 0;
end;

procedure TGenericNode.ExchangeChildren(Index1, Index2: integer);
var
  Temp: specialize TGenericNode<T>;
begin
  Temp := FChildren[Index1];
  FChildren[Index1] := FChildren[Index2];
  FChildren[Index2] := Temp;
end;

procedure TGenericNode.Traverse(const Proc: TNodeProcedure; Recursive: boolean);
var
  Child: specialize TGenericNode<T>;
begin
  Proc(Self);
  if Recursive then
    for Child in FChildren do
      Child.Traverse(Proc);
end;

procedure TGenericNode.Sort(const CompareFunc: TCompareFunction; Recursive: boolean);
var
  Child: specialize TGenericNode<T>;
begin
  if Recursive then
    for Child in FChildren do
      Child.Sort(CompareFunc);
  QuickSort(CompareFunc, 0, High(FChildren));
end;

end.
