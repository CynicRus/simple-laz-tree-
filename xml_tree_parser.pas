unit xml_tree_parser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,streamex, Generics.Collections, generics_tree;

type
  TXmlTreeAttribute = class
  public
    Name: string;
    Value: string;
  end;

  { TXmlTreeNode }

  TXmlTreeNode = class(specialize TGenericNode<string>)
  private
    FAttributes: specialize TList<TXmlTreeAttribute>;
    FIsCData: boolean;
    function GetAttribute(const AttrName: string): string;
    function GetAttributesCount: SizeInt;
    procedure SetAttr(const AttrName: string; const Value: string);
  public
    NodeName: string;
    constructor Create;
    destructor Destroy; override;
    function AddChildNode(const Name: string): TXmlTreeNode;
    function Find(Name: string): TXmlTreeNode; overload;
    function Find(Name, Attribute, Value: string): TXmlTreeNode; overload;
    function SetAttribute(const AttrName: string; const Value: string): TXmlTreeNode;
    function HasAttribute(const AttrName: string): boolean;
    property IsCData: boolean read FIsCData write FIsCData;
    property AttrCount: SizeInt read GetAttributesCount;
    property Attributes[const AttrName: string]: string read GetAttribute write SetAttr;
      default;
  end;

  TXMLTreeDocument = class
  private
    FRoot: TXmlTreeNode;
    FHeader: TXmlTreeNode;
    procedure ParseStream(Stream: TStream);
    function Escape(Value: string): string;
    function UnEscape(Value: string): string;
    procedure TraverseXml(Stream: TStream; Indentation: string; CurrentNode: TXmlTreeNode);
  public
    procedure SetHeader(Version: string; Encoding: string);
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromStream(Stream: TStream);
    procedure SaveToStream(Stream: TStream);
    property Root: TXmlTreeNode read FRoot;
  end;

implementation

{ TXmlTreeNode }

constructor TXmlTreeNode.Create;
begin
  FAttributes := specialize TList<TXmlTreeAttribute>.Create;
  inherited Create('');
end;

destructor TXmlTreeNode.Destroy;
var
  Attr: TXmlTreeAttribute;
begin
  for Attr in FAttributes do
    Attr.Free;
  FAttributes.Free;
  inherited Destroy;
end;

function TXmlTreeNode.GetAttribute(const AttrName: string): string;
var
  Attr: TXmlTreeAttribute;
begin
  Result := '';
  for Attr in FAttributes do
    if SameText(Attr.Name, AttrName) then
      Exit(Attr.Value);
end;

function TXmlTreeNode.GetAttributesCount: SizeInt;
begin
  Result := FAttributes.Count;
end;

procedure TXmlTreeNode.SetAttr(const AttrName: string; const Value: string);
var
  Attr: TXmlTreeAttribute;
begin
  for Attr in FAttributes do
    if SameText(Attr.Name, AttrName) then
    begin
      Attr.Value := Value;
      Exit;
    end;

  Attr := TXmlTreeAttribute.Create;
  Attr.Name := AttrName;
  Attr.Value := Value;
  FAttributes.Add(Attr);
end;

function TXmlTreeNode.AddChildNode(const Name: string): TXmlTreeNode;
begin
  Result := TXmlTreeNode.Create;
  Result.NodeName := Name;
  Result.Parent := Self;
  Adopt(Result);
end;

function TXmlTreeNode.Find(Name: string): TXmlTreeNode;
var
  Child: TXmlTreeNode;
  i: integer;
begin
  Result := nil;
  for i := 0 to self.ChildCount - 1 do
  begin
    Child := TXmlTreeNode(Children[i]);
    if SameText(Child.NodeName, Name) then
      Exit(Child);
  end;
end;

function TXmlTreeNode.Find(Name, Attribute, Value: string): TXmlTreeNode;
var
  Child: TXmlTreeNode;
  i: integer;
begin
  Result := nil;
  for i := 0 to self.ChildCount - 1 do
  begin
    Child := TXmlTreeNode(Children[i]);
    if SameText(Child.NodeName, Name) and Child.HasAttribute(Attribute) and
      (Child.Attributes[Attribute] = Value) then
      Exit(Child);
  end;

end;

function TXmlTreeNode.SetAttribute(const AttrName: string; const Value: string): TXmlTreeNode;
begin
  Attributes[AttrName] := Value;
  Result := Self;
end;

function TXmlTreeNode.HasAttribute(const AttrName: string): boolean;
begin
  Result := GetAttribute(AttrName) <> '';
end;

{ TXMLTreeDocument }

constructor TXMLTreeDocument.Create;
begin
  FRoot := TXmlTreeNode.Create;
  FHeader := TXmlTreeNode.Create;
end;

destructor TXMLTreeDocument.Destroy;
begin
  FRoot.Free;
  FHeader.Free;
  inherited Destroy;
end;

procedure TXMLTreeDocument.SetHeader(Version: string; Encoding: string);
begin
  FHeader.NodeName := '?xml';
  FHeader.SetAttribute('version', Version);
  FHeader.SetAttribute('encoding', Encoding);
end;

procedure TXMLTreeDocument.LoadFromFile(const FileName: string);
var
  FileStream: TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead);
  try
    LoadFromStream(FileStream);
  finally
    FileStream.Free;
  end;
end;

procedure TXMLTreeDocument.SaveToFile(const FileName: string);
var
  FileStream: TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(FileStream);
  finally
    FileStream.Free;
  end;
end;

procedure TXMLTreeDocument.LoadFromStream(Stream: TStream);
begin
  ParseStream(Stream);
end;

procedure TXMLTreeDocument.SaveToStream(Stream: TStream);
begin
  if Assigned(FHeader) then
    TraverseXml(Stream, '', FHeader);
  if Assigned(FRoot) then
    TraverseXml(Stream, '', FRoot);
end;

procedure TXMLTreeDocument.ParseStream(Stream: TStream);
var
  Reader: TStreamReader;
  Line: string;
  IsTag, IsText, IsComment, IsCData, IsDoctype: Boolean;
  Tag, Text: string;
  Parent, Node: TXmlTreeNode;
  Attribute: TXmlTreeAttribute;
  ALine, Attr, AttrText: string;
  P: Integer;
  IsSelfClosing, IsQuote: Boolean;

  function GetText(var Line: string; StartStr: string; StopChar: Char): string;
  var
    Chr: Char;
  begin
    while (Length(Line) > 0) and ((Line[1] <> StopChar) or IsQuote) do
    begin
      Chr := Line[1];
      if Chr = '"' then
        IsQuote := not IsQuote;
      StartStr := StartStr + Chr;
      Delete(Line, 1, 1);
    end;
    Result := StartStr;
  end;

begin
  if Assigned(FRoot) then
    FRoot.Free;

  IsTag := False;
  IsText := False;
  IsQuote := False;
  IsComment := False;
  IsCData := False;
  IsDoctype := False;
  Node := nil;

  Reader := TStreamReader.Create(Stream);

  try
    while not Reader.Eof do
    begin
      Line := Reader.ReadLine;

      while Length(Line) > 0 do
      begin

        if not IsTag and not IsText and not IsComment and not IsCData and not IsDoctype then
        begin
          while (Length(Line) > 0) and (Line[1] <> '<') do
            Delete(Line, 1, 1);

          if Length(Line) > 0 then
          begin
            IsTag := True;
            Delete(Line, 1, 1);
            Tag := '';

            if Length(Line) >= 3 then
            begin
              if Copy(Line, 1, 3) = '!--' then
              begin
                IsTag := False;
                IsComment := True;
                Delete(Line, 1, 3);
              end
              else if Copy(Line, 1, 8) = '![CDATA[' then
              begin
                IsTag := False;
                IsCData := True;
                Delete(Line, 1, 8);
                Text := '';
              end
              else if Copy(Line, 1, 7) = '!DOCTYPE' then
              begin
                IsTag := False;
                IsDoctype := True;
                Tag := GetText(Line, Tag, '>');
                Delete(Line, 1, 1);
              end;
            end;
          end;
        end;

        if IsTag then
        begin
          Tag := GetText(Line, Tag, '>');

          if (Length(Line) > 0) and (Line[1] = '>') then
          begin
            Delete(Line, 1, 1);
            IsTag := False;

            if (Length(Tag) > 0) and (Tag[1] = '/') then
              Node := TXmlTreeNode(Node.Parent)
            else
            begin
              Parent := Node;
              IsText := True;
              IsQuote := False;

              Node := TXmlTreeNode.Create;
              if LowerCase(Copy(Tag, 1, 4)) = '?xml' then
              begin
                Tag := TrimRight(Tag);
                if Tag[Length(Tag)] = '?' then
                  Delete(Tag, Length(Tag), 1);
                if Assigned(FHeader) then
                  FHeader.Free;
                FHeader := Node;
              end;

              if (Length(Tag) > 0) and (Tag[Length(Tag)] = '/') then
              begin
                IsSelfClosing := True;
                Delete(Tag, Length(Tag), 1);
              end
              else
                IsSelfClosing := False;

              P := Pos(' ', Tag);
              if P <> 0 then
              begin
                ALine := Tag;
                Delete(Tag, P, Length(Tag));
                Delete(ALine, 1, P);

                while Length(ALine) > 0 do
                begin
                  Attr := GetText(ALine, '', '=');
                  AttrText := GetText(ALine, '', ' ');

                  if Length(AttrText) > 0 then
                  begin
                    Delete(AttrText, 1, 1);

                    if AttrText[1] = '"' then
                    begin
                      Delete(AttrText, 1, 1);
                      if AttrText[Length(AttrText)] = '"' then
                        Delete(AttrText, Length(AttrText), 1);
                    end;
                  end;

                  if Length(ALine) > 0 then
                    Delete(ALine, 1, 1);

                  if not ((Node = FHeader) and (Attr = '?')) then
                  begin
                    Attribute := TXmlTreeAttribute.Create;
                    Attribute.Name := Attr;
                    Attribute.Value := AttrText;
                    Node.FAttributes.Add(Attribute);
                  end;
                  IsQuote := False;
                end;
              end;

              Node.NodeName := Tag;
              Node.Parent := Parent;
              if Assigned(Parent) then
                Parent.Adopt(Node)
              else if Node = FHeader then
              begin
                IsText := False;
                Node := nil;
              end
              else
                FRoot := Node;

              Text := '';
              if IsSelfClosing then
                Node := TXmlTreeNode(Node.Parent);
            end;
          end;
        end;

        if IsText then
        begin
          Text := GetText(Line, Text, '<');
          if (Length(Line) > 0) and (Line[1] = '<') then
          begin
            IsText := False;
            while (Length(Text) > 0) and (Text[1] = ' ') do
              Delete(Text, 1, 1);
            Node.Data := UnEscape(Text);
          end;
        end;

        if IsComment then
        begin
          Text := GetText(Line, Text, '-');
          if (Length(Line) > 2) and (Copy(Line, 1, 2) = '->') then
          begin
            IsComment := False;
            Delete(Line, 1, 2);
            Text := '';
            continue;
          end;
        end;

        if IsCData then
        begin
          Text := GetText(Line, Text, ']');
          if (Length(Line) > 2) and (Copy(Line, 1, 2) = ']>') then
          begin
            IsCData := False;
            Delete(Line, 1, 2);
            Node.Data := Text;
            Node.IsCData := True;
          end;
        end;

        if IsDoctype then
        begin
          IsDoctype := False;
          continue;
        end;
      end;
    end;
  finally
    Reader.Free;
  end;
end;


function TXMLTreeDocument.Escape(Value: string): string;
begin
  Result := StringReplace(Value, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function TXMLTreeDocument.UnEscape(Value: string): string;
begin
  Result := StringReplace(Value, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

procedure TXMLTreeDocument.TraverseXml(Stream: TStream; Indentation: string; CurrentNode: TXmlTreeNode);
var
  XmlTreeAttribute: TXmlTreeAttribute;
  IsEmptyNode: boolean;
  ChildIndex: integer;
  StringBuilder: TStringBuilder;
begin
  if CurrentNode = nil then
    Exit;

  StringBuilder := TStringBuilder.Create;
  try
    if CurrentNode.IsCData then
    begin
      StringBuilder.Append(Indentation)
                   .Append('<![CDATA[')
                   .Append(CurrentNode.Data)
                   .Append(']]>');
      Stream.Write(StringBuilder.ToString[1], StringBuilder.Length);
      Exit;
    end;

    StringBuilder.Append(Indentation)
                 .Append('<')
                 .Append(CurrentNode.NodeName);

    for XmlTreeAttribute in CurrentNode.FAttributes do
      StringBuilder.Append(' ')
                   .Append(XmlTreeAttribute.Name)
                   .Append('="')
                   .Append(XmlTreeAttribute.Value)
                   .Append('"');

    IsEmptyNode := (CurrentNode.ChildCount = 0) and (CurrentNode.Data = '');

    if IsEmptyNode then
    begin
      StringBuilder.Append(' />').Append(sLineBreak);
      Stream.Write(StringBuilder.ToString[1], StringBuilder.Length);
      Exit;
    end
    else
    begin
      StringBuilder.Append('>');
      Stream.Write(StringBuilder.ToString[1], StringBuilder.Length);

      if (CurrentNode.ChildCount > 0) and (CurrentNode.GetFirstChild.Data = '') or
          (CurrentNode.AttrCount > 0) then
      begin
        Stream.Write(sLineBreak[1], Length(sLineBreak));
      end;
    end;

    if CurrentNode.Data <> '' then
    begin
      StringBuilder.Clear;
      StringBuilder.Append(Escape(CurrentNode.Data));
      Stream.Write(StringBuilder.ToString[1], StringBuilder.Length);
    end;

    if not IsEmptyNode then
    begin
      for ChildIndex := 0 to CurrentNode.ChildCount - 1 do
        TraverseXml(Stream, Indentation, CurrentNode.Children[ChildIndex] as TXmlTreeNode);

      StringBuilder.Clear;
      StringBuilder.Append(Indentation)
                   .Append('</')
                   .Append(CurrentNode.NodeName)
                   .Append('>')
                   .Append(sLineBreak);
      Stream.Write(StringBuilder.ToString[1], StringBuilder.Length);
    end;
  finally
    StringBuilder.Free;
  end;
end;

end.
