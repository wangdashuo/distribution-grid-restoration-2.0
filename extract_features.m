function f = extract_features(e, sys, paths, downstream)
% 9 维特征（原 7 维 + 关键负荷 2 维）
    ds = downstream{e};
    if isempty(ds)
        f = zeros(1, 9);  return;
    end

    Psum  = sum(sys.Pload_kW(ds)) / 1000;
    nDown = numel(ds);
    crit  = sum(sys.Pload_kW(ds) > 150) / max(nDown,1);
    dist  = numel(paths{sys.to(e)});
    Zmag  = sqrt(sys.R(e)^2 + sys.X(e)^2);
    avgP  = Psum / max(nDown,1);
    wPsum = sum(sys.wImp(ds) .* sys.Pload_kW(ds)) / 1000;

    % 新增两维
    dcIdx  = find(strcmp(sys.nodeType, '数据中心'));
    hosIdx = find(strcmp(sys.nodeType, '医院'));
    isCritUp = double(any(ismember(ds, [dcIdx; hosIdx])));   % 下游含关键负荷？
    nCrit    = numel(intersect(ds, [dcIdx; hosIdx]));         % 关键负荷节点数

    f = [Psum, nDown, crit, dist, Zmag, avgP, wPsum, isCritUp, nCrit];
end