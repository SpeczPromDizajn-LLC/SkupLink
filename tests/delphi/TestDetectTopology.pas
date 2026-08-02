unit TestDetectTopology;

interface

uses
  DUnitX.TestFramework,
  uUpsModels;

type
  [TestFixture]
  TDetectTopologyTests = class
  public
    [Test]
    procedure SinglePhase_WhenBothAtMostOne;
    [Test]
    procedure ThreePhaseInOut_WhenBothAtLeastThree;
    [Test]
    procedure ThreePhaseInSingleOut_WhenInThreeOutOne;
    [Test]
    procedure Unknown_WhenMixedUnsupported;
  end;

implementation

procedure TDetectTopologyTests.SinglePhase_WhenBothAtMostOne;
begin
  Assert.AreEqual(Ord(utSinglePhase), Ord(TUpsSnapshot.DetectTopology(0, 0)));
  Assert.AreEqual(Ord(utSinglePhase), Ord(TUpsSnapshot.DetectTopology(1, 1)));
end;

procedure TDetectTopologyTests.ThreePhaseInOut_WhenBothAtLeastThree;
begin
  Assert.AreEqual(Ord(utThreePhaseInOut), Ord(TUpsSnapshot.DetectTopology(3, 3)));
  Assert.AreEqual(Ord(utThreePhaseInOut), Ord(TUpsSnapshot.DetectTopology(3, 4)));
end;

procedure TDetectTopologyTests.ThreePhaseInSingleOut_WhenInThreeOutOne;
begin
  Assert.AreEqual(Ord(utThreePhaseInSingleOut), Ord(TUpsSnapshot.DetectTopology(3, 1)));
  Assert.AreEqual(Ord(utThreePhaseInSingleOut), Ord(TUpsSnapshot.DetectTopology(3, 0)));
end;

procedure TDetectTopologyTests.Unknown_WhenMixedUnsupported;
begin
  Assert.AreEqual(Ord(utUnknown), Ord(TUpsSnapshot.DetectTopology(2, 1)));
  Assert.AreEqual(Ord(utUnknown), Ord(TUpsSnapshot.DetectTopology(1, 3)));
end;

end.
