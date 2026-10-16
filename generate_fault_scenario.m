function fault = generate_fault_scenario(sys, cfg)
% 生成多点连锁故障（加权，关键负荷上游更易被切）
%
% 权重规则：
%   - 下游含数据中心：权重 ×8
%   - 下游含医院    ：权重 ×5
%   - 下游含大工业  ：权重 ×2
%   - 其它          ：权重 ×1
%
% 这样确保关键负荷"真的被威胁"，S1-S4 的优化才能显出区别

    nB = sys.nBranch;
    [~, downstream] = build_topology(sys);

    % ---- 给每条候选支路分配权重 ----
    dcIdx  = find(strcmp(sys.nodeType, '数据中心'));
    hosIdx = find(strcmp(sys.nodeType, '医院'));

    candW = zeros(nB, 1);
    for e = 1:nB
        if sys.isTie(e), continue; end
        ds = downstream{e};
        if isempty(ds), continue; end
        if sum(sys.Pload_kW(ds)) < 10, continue; end   % 下游至少 10 kW

        w = 1;
        if any(ismember(ds, dcIdx)),  w = w * 8; end   % 数据中心
        if any(ismember(ds, hosIdx)), w = w * 5; end   % 医院
        if any(sys.VOLL(ds) >= 1000 & sys.VOLL(ds) < 5000)
            w = w * 2;                                  % 大工业
        end
        candW(e) = w;
    end

    cand = find(candW > 0);
    if numel(cand) < cfg.minFaults
        error('候选故障线路不足');
    end

    % ---- 按权重不放回抽样 ----
    k = randi([cfg.minFaults, min(cfg.maxFaults, numel(cand))]);

    fault = false(nB, 1);
    w = candW(cand);
    for i = 1:k
        p = w / sum(w);              % 归一化权重
        idx = find(rand <= cumsum(p), 1);
        fault(cand(idx)) = true;
        w(idx) = 0;                  % 已选中，权重清零
        if sum(w) < 1e-6, break; end
    end
end