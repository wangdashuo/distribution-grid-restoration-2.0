function res = solve_restoration_fast(fault, wAI, sys, cfg)
% AI-only 快速恢复决策（含联络开关重构启发式）
%   1) 按 AI 打分排序故障线路
%   2) 每时段按序分配 nCrew 个班组修复
%   3) 贪心闭合联络开关（不成环才闭合，恢复更多加权负荷优先）
%   4) BFS 判断连通性，输出 α

    nB = sys.nBranch;  nN = sys.nNode;  T = cfg.T;

    %% ===== 初始化字段 =====
    res.alpha   = zeros(nN, T);
    res.y       = zeros(nB, T);
    res.s       = zeros(nB, T);
    res.d       = zeros(nB, T);
    res.sol     = [];
    res.scene   = struct('useReliability', true, ...
                         'useImportance',  true, ...
                         'useAI',          true, ...
                         'method',         'AI-fast');
    res.ENS     = 0;   res.ENS_w    = 0;
    res.ENS_DC  = 0;   res.ENS_Hos  = 0;
    res.ENS_Ind = 0;   res.ENS_Res  = 0;
    res.ENS_crit= 0;
    res.obj     = 0;
    res.success = true;

    %% ===== 步骤1：按 AI 打分排序故障线路 =====
    faultIdx = find(fault);
    if isempty(faultIdx), return; end

    scores = wAI(faultIdx);
    [~, order] = sort(scores, 'descend');
    faultSorted = faultIdx(order);

    %% ===== 步骤2：按优先级分配修复时段 =====
    for i = 1:numel(faultSorted)
        t = min(ceil(i / cfg.nCrew), T);
        res.s(faultSorted(i), t) = 1;
    end

    %% ===== 步骤3：逐时段判断供电 + 联络重构 =====
    % 记录每时段最终采用的联络开关状态（供可视化）
    tieState = false(nB, T);

    for t = 1:T
        % 已修复线路
        repaired = any(res.s(:, 1:t) > 0.5, 2);
        lineOK = (~fault) | repaired;
        lineOK(sys.isTie) = false;      % 联络开关初始全开

        % ---- 贪心闭合联络开关 ----
        lineOK = greedily_close_ties(sys, lineOK);

        % 保存本时段联络状态
        tieState(:, t) = lineOK;

        % BFS 判断供电
        powerOn = bfs_connect(sys, lineOK);
        res.alpha(~powerOn, t) = 1;
    end

    %% ===== 步骤4：更新 y =====
    res.y = double(tieState);

    %% ===== 步骤5：汇总（分类别）=====
    dcIdx  = find(strcmp(sys.nodeType,'数据中心'));
    hosIdx = find(strcmp(sys.nodeType,'医院'));

    ens = 0;  loss_USD = 0;
    ens_DC = 0;  ens_Hos = 0;  ens_Ind = 0;  ens_Res = 0;

    for t = 1:T
        for j = 2:nN
            if res.alpha(j,t) > 0.5
                MWh_j = (sys.Pload_kW(j) / 1000) * cfg.dt;
                ens      = ens      + MWh_j;
                loss_USD = loss_USD + sys.VOLL(j) * MWh_j;

                if ismember(j, dcIdx)
                    ens_DC = ens_DC + MWh_j;
                elseif ismember(j, hosIdx)
                    ens_Hos = ens_Hos + MWh_j;
                elseif sys.VOLL(j) >= 1000
                    ens_Ind = ens_Ind + MWh_j;
                else
                    ens_Res = ens_Res + MWh_j;
                end
            end
        end
    end

    res.ENS      = ens;
    res.ENS_w    = loss_USD;
    res.ENS_DC   = ens_DC;
    res.ENS_Hos  = ens_Hos;
    res.ENS_Ind  = ens_Ind;
    res.ENS_Res  = ens_Res;
    res.ENS_crit = ens_DC + ens_Hos;
    res.obj      = loss_USD;
end

%% ============ 贪心闭合联络开关（不成环，优先加权负荷）============
function lineOK = greedily_close_ties(sys, lineOK)
    tieIdx = find(sys.isTie);

    % 计算当前加权负荷
    powerOn = bfs_connect(sys, lineOK);
    curW = weighted_power(sys, powerOn);

    improved = true;
    while improved
        improved = false;
        bestGain = 0;
        bestTie  = 0;

        for ti = tieIdx'
            if lineOK(ti), continue; end

            i = sys.from(ti);  j = sys.to(ti);

            % 检查闭合是否会成环：如果两端已连通，就不能闭
            if is_connected(sys, lineOK, i, j)
                continue;
            end

            % 试闭合
            lineOK_try = lineOK;
            lineOK_try(ti) = true;
            powerOn_try = bfs_connect(sys, lineOK_try);
            wTry = weighted_power(sys, powerOn_try);
            gain = wTry - curW;

            if gain > bestGain
                bestGain = gain;
                bestTie  = ti;
            end
        end

        if bestTie > 0
            lineOK(bestTie) = true;
            curW = curW + bestGain;
            improved = true;
        end
    end
end

%% ============ 加权负荷 ============
function w = weighted_power(sys, powerOn)
    w = 0;
    for j = find(powerOn)'
        w = w + sys.Pload_kW(j) * max(sys.VOLL(j), 1);
    end
end

%% ============ 检查 a、b 两点是否已连通 ============
function yes = is_connected(sys, lineOK, a, b)
    if a == b, yes = true; return; end
    nN = sys.nNode;
    visited = false(nN, 1);
    visited(a) = true;
    queue = a;
    while ~isempty(queue)
        v = queue(1);  queue(1) = [];
        for e = 1:sys.nBranch
            if ~lineOK(e), continue; end
            u = 0;
            if sys.from(e) == v, u = sys.to(e); end
            if sys.to(e)   == v, u = sys.from(e); end
            if u > 0 && ~visited(u)
                if u == b, yes = true; return; end
                visited(u) = true;
                queue(end+1) = u; %#ok<AGROW>
            end
        end
    end
    yes = false;
end

%% ============ BFS 连通性 ============
function powerOn = bfs_connect(sys, lineOK)
    nN = sys.nNode;
    powerOn = false(nN, 1);
    powerOn(sys.root) = true;
    adj = cell(nN, 1);
    for e = 1:sys.nBranch
        if lineOK(e)
            i = sys.from(e);  j = sys.to(e);
            adj{i}(end+1) = j;   %#ok<AGROW>
            adj{j}(end+1) = i;   %#ok<AGROW>
        end
    end
    queue = sys.root;
    while ~isempty(queue)
        v = queue(1);  queue(1) = [];
        for u = adj{v}
            if ~powerOn(u)
                powerOn(u) = true;
                queue(end+1) = u; %#ok<AGROW>
            end
        end
    end
end