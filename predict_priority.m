function w = predict_priority(model, fault, sys, cfg) %#ok<INUSD>
    nB = sys.nBranch;  w = zeros(nB, 1);
    idx = find(fault);
    if isempty(idx), return; end

    [paths, downstream] = build_topology(sys);

    nFeat = numel(model.mu);
    X = zeros(numel(idx), nFeat);
    for i = 1:numel(idx)
        X(i,:) = extract_features(idx(i), sys, paths, downstream);
    end

    Xn = (X - model.mu) ./ model.sigma;
    Xn = [ones(size(Xn,1),1), Xn];
    p = Xn * model.theta;
    w(idx) = max(0, min(1, p));
end