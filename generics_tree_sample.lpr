program generics_tree_sample;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}

uses {$IFDEF UNIX}
  cthreads, {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  DateUtils,
  generics_tree, xml_tree_parser{ you can add units after this };

type

  TDataRecord = record
    ID: integer;
    Name: string;
    procedure Initialize(AID: integer; const AName: string);
    procedure ChangeName(const AName: string);
  end;

  DataRecordNode = specialize TGenericNode<TDataRecord>;

  // Example class implementing TCustomApplication
  { TTreeSampleApp }

  TTreeSampleApp = class(TCustomApplication)
  private
    function SortIntegerNodes(const A, B: specialize TGenericNode<integer>): integer;
    procedure TestTreeWithInteger;
    procedure TestTreeWithString;
    procedure TestTreeWithCustomRecord;
    procedure TestSiblings;
    procedure TestSortingAndTraversalWithInteger;
    procedure TestMoveNodeWithInteger;
    procedure TestDeleteChildrenWithInteger;
    procedure TestXMLParser;
    procedure TestXMLFile;
    procedure DisplayIntegerNode(const Node: specialize TGenericNode<integer>);
    procedure DisplayStringNode(const Node: specialize TGenericNode<string>);
    procedure DisplayCustomRecordNode(const Node: DataRecordNode);
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

  procedure TDataRecord.Initialize(AID: integer; const AName: string);
  begin
    ID := AID;
    Name := AName;
  end;

  procedure TDataRecord.ChangeName(const AName: string);
  begin
    Name := AName;
  end;

  function TTreeSampleApp.SortIntegerNodes(
  const A, B: specialize TGenericNode<integer>): integer;
  begin
    Result := A.Data - B.Data;
  end;

  procedure TTreeSampleApp.DisplayIntegerNode(
  const Node: specialize TGenericNode<integer>);
  begin
    Writeln('Node data: ', Node.Data);
  end;

  procedure TTreeSampleApp.DisplayStringNode(const Node: specialize TGenericNode<string>);
  begin
    Writeln('Node data: ', Node.Data);
  end;

    procedure TTreeSampleApp.DisplayCustomRecordNode(const Node: DataRecordNode);
  begin
    Writeln('Node data: ID=', Node.Data.ID, ', Name=', Node.Data.Name);
  end;

  procedure TTreeSampleApp.TestTreeWithInteger;
  var
    Root, Child1, Child2: specialize TGenericNode<integer>;
  begin
    Writeln('Testing tree with Integer...');

    Root := specialize TGenericNode<integer>.Create(10);
    try
      Child1 := Root.AddChild(20);
      Child2 := Root.AddChild(30);

      Writeln('Root data: ', Root.Data);
      Writeln('Child1 data: ', Child1.Data);
      Writeln('Child2 data: ', Child2.Data);

      Child1.Data := 25;

      Root.Traverse(@DisplayIntegerNode);

    finally
      Root.Free;
    end;
  end;

  procedure TTreeSampleApp.TestTreeWithString;
  var
    Root, Child1, Child2: specialize TGenericNode<string>;
  begin
    Writeln('Testing tree with String...');

    Root := specialize TGenericNode<string>.Create('RootNode');
    try
      Child1 := Root.AddChild('ChildNode1');
      Child2 := Root.AddChild('ChildNode2');

      Writeln('Root data: ', Root.Data);
      Writeln('Child1 data: ', Child1.Data);
      Writeln('Child2 data: ', Child2.Data);

      Child1.Data := 'UpdatedChildNode1';

      Root.Traverse(@DisplayStringNode);

    finally
      Root.Free;
    end;
  end;

  procedure TTreeSampleApp.TestTreeWithCustomRecord;
  var
    Root, Child1, Child2: DataRecordNode;
    R1, R2: TDataRecord;
  begin
    Writeln('Testing tree with custom record...');

    Root := DataRecordNode.Create;
    try
      Root.Data.Initialize(1, 'RootRecord');

      Child1 := Root.AddChild(R1);
      Child1.Data.Initialize(2, 'ChildRecord1');

      Child2 := Root.AddChild(R2);
      Child2.Data.Initialize(3, 'ChildRecord2');

      Writeln('Root data: ID=', Root.Data.ID, ', Name=', Root.Data.Name);
      Writeln('Child1 data: ID=', Child1.Data.ID, ', Name=', Child1.Data.Name);
      Writeln('Child2 data: ID=', Child2.Data.ID, ', Name=', Child2.Data.Name);

      Child1.Data.ChangeName('UpdatedChildRecord1');

      // Traverse and display data
      Root.Traverse(@DisplayCustomRecordNode);

    finally
      Root.Free;
    end;
  end;

  procedure TTreeSampleApp.TestSiblings;
  var
    Root, Child1, Child2, Sibling: specialize TGenericNode<integer>;
  begin
    Writeln('Testing sibling relationships...');

    Root := specialize TGenericNode<integer>.Create(10);
    try
      // Add children
      Child1 := Root.AddChild(20);
      Child2 := Root.AddChild(30);

      Sibling := Child1.GetNextSibling;
      if Sibling <> nil then
        Writeln('Next sibling of Child1: ', Sibling.Data)
      else
        Writeln('Child1 has no next sibling');

      Sibling := Child2.getPrevSibling;
      if Sibling <> nil then
        Writeln('Previous sibling of Child2: ', Sibling.Data)
      else
        Writeln('Child2 has no previous sibling');
    finally
      Root.Free;
    end;
  end;

  procedure TTreeSampleApp.TestSortingAndTraversalWithInteger;
  var
    Root, Child1, Child2, Child3: specialize TGenericNode<integer>;
  begin
    Writeln('Testing sorting and traversal with Integer...');

    // Create root
    Root := specialize TGenericNode<integer>.Create(10);
    try
      // Add children
      Child1 := Root.AddChild(30);
      Child2 := Root.AddChild(20);
      Child3 := Root.AddChild(40);

      // Traverse and display unsorted data
      Writeln('Unsorted traversal:');
      Root.Traverse(@DisplayIntegerNode);

      // Sort children of root node
      Root.Sort(@SortIntegerNodes
        );

      // Traverse and display sorted data
      Writeln('Sorted traversal:');
      Root.Traverse(@DisplayIntegerNode);

    finally
      Root.Free;
    end;
  end;

  procedure TTreeSampleApp.TestMoveNodeWithInteger;
  var
    Root, Child1, Child2, Child3: specialize TGenericNode<integer>;
  begin
    Writeln('Testing node movement with Integer...');

    // Create root
    Root := specialize TGenericNode<integer>.Create(10);
    try
      // Add children
      Child1 := Root.AddChild(20);
      Child2 := Root.AddChild(30);
      Child3 := Child1.AddChild(40); // Adding a grandchild

      // Initial traverse
      Writeln('Initial structure:');
      Root.Traverse(@DisplayIntegerNode);

      // Move Child3 from Child1 to Root
      Child3.MoveTo(Root, naAddChild);

      // Traverse and display after move
      Writeln('Structure after moving Child3:');
      Root.Traverse(@DisplayIntegerNode);

    finally
      Root.Free;
    end;
  end;

  procedure TTreeSampleApp.TestDeleteChildrenWithInteger;
  var
    Root, Child1, Child2: specialize TGenericNode<integer>;
  begin
    Writeln('Testing deletion of children with Integer...');

    // Create root
    Root := specialize TGenericNode<integer>.Create(10);
    try
      // Add children
      Child1 := Root.AddChild(20);
      Child2 := Root.AddChild(30);

      // Initial traverse
      Writeln('Initial structure:');
      Root.Traverse(@DisplayIntegerNode);

      // Delete Children
      Root.DeleteChildren;

      // Traverse and display after deletion
      Writeln('Structure after deleting children:');
      Root.Traverse(@DisplayIntegerNode);

    finally
      Root.Free;
    end;
  end;

procedure TTreeSampleApp.TestXMLParser;
var
  XmlDoc: TXMLTreeDocument;
  RootNode, BookNode, FoundNode: TXmlTreeNode;
  i: Integer;
begin
  Writeln('Test of XML parser...');
  XmlDoc := TXMLTreeDocument.Create;
  XmlDoc.SetHeader('1.0', 'UTF-8');
  try
    RootNode := XmlDoc.Root;
    RootNode.NodeName := 'library';
    for i := 1 to 10 do
    begin
      BookNode := RootNode.AddChildNode('book');
      BookNode.SetAttribute('id', 'bk' + IntToStr(100 + i));
      BookNode.AddChildNode('author').Data := 'Author ' + IntToStr(i);
      BookNode.AddChildNode('title').Data := 'Title ' + IntToStr(i);
    end;

    FoundNode := RootNode.Find('book');
    if Assigned(FoundNode) then
      Writeln('found book with ID: ', FoundNode.Attributes['id']);

    FoundNode := RootNode.Find('book', 'id', 'bk102');
    if Assigned(FoundNode) then
      Writeln('Found book by concrete title: ',
              FoundNode.Find('title').Data);

    if Assigned(FoundNode) then
    begin
      FoundNode.SetAttribute('id', 'bk999');
      Writeln('Changed id of book: ', FoundNode.Attributes['id']);
    end;

    if Assigned(RootNode.Find('book', 'id', 'bk105')) then
    begin
      RootNode.Find('book', 'id', 'bk105').Delete;
      Writeln('Book with ID bk105 deleted');
    end;

    XmlDoc.SaveToFile('test.xml');

  finally
    XmlDoc.Free;
  end;
end;

procedure TTreeSampleApp.TestXMLFile;
var
  XmlDoc: TXmlTreeDocument;
  RootNode, CurrentNode: TXmlTreeNode;
  FileName: string;
  BookCount: Integer;
begin
  FileName := '1mb.xml';
  Writeln('Testing of xml file: ', FileName);

  XmlDoc := TXmlTreeDocument.Create;
  try
    XmlDoc.LoadFromFile(FileName);
    RootNode := XmlDoc.Root;
    XmlDoc.SaveToFile('test1.xml');
    writeln(inttostr(RootNode.ChildCount));
    if Assigned(RootNode) then
    begin
      Writeln('Root node: ', RootNode.NodeName);
      BookCount := 0;

      CurrentNode := RootNode.Find('book');
      while Assigned(CurrentNode) do
      begin
        Inc(BookCount);
        Writeln('Book ', BookCount, ': title = ', CurrentNode.Find('title').Data);
        CurrentNode := CurrentNode.GetNextSibling as TXmlTreeNode;
      end;

      Writeln('Books found: ', BookCount);
    end
    else
    begin
      Writeln('Error: Root node not found.');
    end;

  finally
    XmlDoc.Free;
  end;
end;


  { TTreeSampleApp }

  procedure TTreeSampleApp.DoRun;
  begin
    TestTreeWithInteger;
    TestTreeWithString;
    TestTreeWithCustomRecord;
    TestSiblings;
    TestSortingAndTraversalWithInteger;
    TestMoveNodeWithInteger;
    TestDeleteChildrenWithInteger;
    TestXMLParser;
    TestXMLFile;
    Terminate; // Stop program loop
  end;

  constructor TTreeSampleApp.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  destructor TTreeSampleApp.Destroy;
  begin
    inherited Destroy;
  end;

  procedure TTreeSampleApp.WriteHelp;
  begin
    Writeln('Usage: ', ExeName, ' -h');
  end;

var
  Application: TTreeSampleApp;
begin
  Application := TTreeSampleApp.Create(nil);
  Application.Title := 'Tree Sample Application';
  Application.Run;
  Application.Free;
end.
