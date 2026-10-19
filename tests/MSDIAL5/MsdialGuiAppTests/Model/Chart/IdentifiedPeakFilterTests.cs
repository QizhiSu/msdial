using CompMs.App.Msdial.Model.Chart;
using CompMs.App.Msdial.Model.DataObj;
using CompMs.MsdialCore.DataObj;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace CompMs.App.Msdial.Model.Chart.Tests;

[TestClass]
public class IdentifiedPeakFilterTests
{
    [TestMethod]
    public void IsIdentified_NonEmptyName_ReturnsTrue() {
        var peak = NewPeak();
        peak.Name = "Glucose";
        Assert.IsTrue(IdentifiedPeakFilter.IsIdentified(peak));
    }

    [TestMethod]
    public void IsIdentified_EmptyName_ReturnsFalse() {
        var peak = NewPeak();
        peak.Name = string.Empty;
        Assert.IsFalse(IdentifiedPeakFilter.IsIdentified(peak));
    }

    [TestMethod]
    public void IsIdentified_NullName_ReturnsFalse() {
        // A freshly constructed ChromatogramPeakFeature has Name = string.Empty,
        // which the filter must treat as not identified.
        var peak = NewPeak();
        Assert.IsFalse(IdentifiedPeakFilter.IsIdentified(peak));
    }

    [TestMethod]
    public void Filter_OnlyRetainsIdentifiedPeaks() {
        var glucose = NewPeak(name: "Glucose");
        var sucrose = NewPeak(name: "Sucrose");
        var unnamed1 = NewPeak();
        var unnamed2 = NewPeak(name: string.Empty);

        var filtered = IdentifiedPeakFilter.Filter(new[] { glucose, sucrose, unnamed1, unnamed2 });

        CollectionAssert.AreEqual(new[] { glucose, sucrose }, new System.Collections.Generic.List<ChromatogramPeakFeatureModel>(filtered));
    }

    private static ChromatogramPeakFeatureModel NewPeak(string? name = null) {
        var peak = new ChromatogramPeakFeatureModel(new ChromatogramPeakFeature());
        if (name is not null) {
            peak.Name = name;
        }
        return peak;
    }
}