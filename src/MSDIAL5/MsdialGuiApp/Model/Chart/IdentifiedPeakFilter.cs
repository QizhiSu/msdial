using CompMs.App.Msdial.Model.DataObj;
using System.Collections.Generic;
using System.Linq;

namespace CompMs.App.Msdial.Model.Chart;

/// <summary>
/// Decides which chromatogram peak features count as "identified" for the
/// "show identified metabolites on TIC" overlay.
/// </summary>
/// <remarks>
/// A peak is considered identified when it carries a non-empty name. This
/// covers peaks named by a library match (Msp or text DB), peaks renamed
/// by the user, and peaks confirmed via the curator. The set unknown
/// action clears <see cref="ChromatogramPeakFeatureModel.Name"/>, so
/// unknown peaks are correctly excluded.
/// </remarks>
internal static class IdentifiedPeakFilter
{
    public static bool IsIdentified(ChromatogramPeakFeatureModel peak) {
        return peak is not null && !string.IsNullOrEmpty(peak.Name);
    }

    public static IEnumerable<ChromatogramPeakFeatureModel> Filter(IEnumerable<ChromatogramPeakFeatureModel> peaks) {
        return peaks.Where(IsIdentified);
    }
}