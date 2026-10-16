function res = make_failed_result(nB, nN, T, scene, sol)
    res.alpha     = nan(nN, T);
    res.y         = nan(nB, T);
    res.s         = nan(nB, T);
    res.d         = nan(nB, T);
    res.sol       = sol;
    res.scene     = scene;
    res.ENS       = NaN;
    res.ENS_w     = NaN;
    res.ENS_DC    = NaN;
    res.ENS_Hos   = NaN;
    res.ENS_Ind   = NaN;
    res.ENS_Res   = NaN;
    res.ENS_crit  = NaN;
    res.obj       = NaN;
    res.success   = false;
end