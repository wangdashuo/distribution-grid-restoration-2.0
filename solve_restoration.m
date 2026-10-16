function res = solve_restoration(fault, wAI, sys, cfg, scene)
% MILP 恢复优化（含联络开关重构 + 分档 VOLL）
%
% scene.useReliability   是否启用可靠性权重 wRel
% scene.useImportance    是否启用分档 VOLL（否则用统一价）
% scene.useAI            是否启用 AI 引导项
%
% 返回字段:
%   .alpha .y .s .d .sol .scene .ENS .ENS_w .obj .success
%   .success = true  → 求解成功，数值有效
%   .success = false → 求解失败，所有数值字段为 NaN

    if nargin < 5 || isempty(scene), scene = struct(); end
    if ~isfield(scene,'useReliability'), scene.useReliability = true;  end
    if ~isfield(scene,'useImportance'),  scene.useImportance  = true;  end
    if ~isfield(scene,'useAI'),          scene.useAI          = false; end

    nB = sys.nBranch;  nN = sys.nNode;  T = cfg.T;
    isTie = sys.isTie;  root = sys.root;
    baseMVA = cfg.baseMVA;  Zbase = cfg.baseKV^2 / baseMVA;

    Pload = sys.Pload_kW   / 1000 / baseMVA;
    Qload = sys.Qload_kVar / 1000 / baseMVA;
    Rpu = sys.R / Zbase;  Xpu = sys.X / Zbase;

    %% -------- 节点权重 --------
    if scene.useImportance
        VOLL_use = sys.VOLL;
    else
        VOLL_use = cfg.VOLL_default * ones(nN, 1);
    end
    VOLL_use = VOLL_use / cfg.VOLL_scale;
    VOLL_use(root) = 0;

    if scene.useReliability
        wRel_use = sys.wRel;
    else
        wRel_use = ones(nN, 1);
    end
    wRel_use(root) = 0;

    %% -------- 变量 --------
    y = binvar(nB, T);   s = binvar(nB, T);   d = binvar(nB, T);
    alpha = sdpvar(nN, T);   P = sdpvar(nB, T);   Q = sdpvar(nB, T);
    v = sdpvar(nN, T);
    C = [];

    %% -------- 修复逻辑 --------
    for e = 1:nB
        if isTie(e)
            C = [C, s(e,:) == 0];
        elseif fault(e)
            C = [C, sum(s(e,:)) <= 1];
            for t = 1:T, C = [C, y(e,t) == sum(s(e,1:t))]; end
        else
            C = [C, s(e,:) == 0];
        end
    end

    %% -------- 班组 --------
    for t = 1:T, C = [C, sum(s(:,t)) <= cfg.nCrew]; end

    %% -------- 方向指示 --------
    for t = 1:T
        for e = 1:nB, C = [C, d(e,t) <= y(e,t)]; end
    end

    %% -------- 拓扑（父节点计数）--------
    for t = 1:T
        for j = 1:nN
            if j == root, C = [C, alpha(j,t) == 0]; continue; end
            pc = 0;
            for e = 1:nB
                if sys.from(e) == j, pc = pc + (y(e,t) - d(e,t)); end
                if sys.to(e) == j,   pc = pc + d(e,t);              end
            end
            C = [C, pc == 1 - alpha(j,t)];
        end
    end

    %% -------- 方向-供电一致 --------
    for t = 1:T
        for e = 1:nB
            i = sys.from(e); j = sys.to(e);
            C = [C, alpha(i,t) <= 1 - d(e,t)];
            C = [C, alpha(j,t) <= (1 - y(e,t)) + d(e,t)];
        end
    end

    %% -------- 电压 --------
    Vmin2 = cfg.Vmin^2;  Vmax2 = cfg.Vmax^2;
    Mv = 1.0;  Mbig = 2.0;
    for t = 1:T
        C = [C, v(root,t) == 1];
        for j = 2:nN
            C = [C, v(j,t) <= Vmax2 + Mv * alpha(j,t)];
            C = [C, v(j,t) >= Vmin2 - Mv * alpha(j,t)];
        end
        for e = 1:nB
            i = sys.from(e); j = sys.to(e);
            expr = v(j,t) - v(i,t) + 2*(Rpu(e)*P(e,t) + Xpu(e)*Q(e,t));
            C = [C,  expr <=  Mbig*(1 - y(e,t))];
            C = [C,  expr >= -Mbig*(1 - y(e,t))];
        end
    end

    %% -------- 功率平衡 --------
    for t = 1:T
        for j = 2:nN
            netP = 0; netQ = 0;
            for e = 1:nB
                if sys.to(e) == j,   netP = netP + P(e,t);  netQ = netQ + Q(e,t); end
                if sys.from(e) == j, netP = netP - P(e,t);  netQ = netQ - Q(e,t); end
            end
            C = [C, netP == Pload(j) * (1 - alpha(j,t))];
            C = [C, netQ == Qload(j) * (1 - alpha(j,t))];
        end
    end

    %% -------- 过载 --------
    Pmax = cfg.Pmax;
    for t = 1:T
        for e = 1:nB
            C = [C, -Pmax*y(e,t) <= P(e,t) <= Pmax*y(e,t)];
            C = [C, -Pmax*y(e,t) <= Q(e,t) <= Pmax*y(e,t)];
        end
    end

    %% -------- 目标函数 --------
    obj = 0;
    for t = 1:T
        for j = 2:nN
            obj = obj + VOLL_use(j) * wRel_use(j) * ...
                        Pload(j) * baseMVA * alpha(j,t) * cfg.dt;
        end
    end
    if scene.useAI
        for e = 1:nB
            for t = 1:T
                obj = obj + cfg.lambda_AI * wAI(e) * t * s(e,t);
            end
        end
    end

    %% -------- 求解 --------
    opts = sdpsettings('solver','intlinprog','verbose',0, ...
                       'intlinprog.MaxTime', 1800);
    sol = optimize(C, obj, opts);

    %% ============ ★ 关键修复1：求解状态判定 ============
    % 求解失败（超时/不可行/未知）时，value(...) 返回残值或 NaN，
    % 必须丢弃！否则会污染 ENS 和后续所有结果。
    if sol.problem ~= 0
        fprintf('    [!] 求解失败: problem=%d, info=%s\n', ...
                sol.problem, sol.info);
        res = make_failed_result(nB, nN, T, scene, sol);
        return;
    end

    %% -------- 提取解 --------
    res = struct();
    res.alpha = value(alpha);
    res.y     = value(y);
    res.s     = value(s);
    res.d     = value(d);
    res.sol   = sol;
    res.scene = scene;

    %% ============ ★ 关键修复2：NaN 二次校验 ============
    if isempty(res.alpha) || any(isnan(res.alpha(:)))
        fprintf('    [!] 解中存在 NaN，视为失败\n');
        res = make_failed_result(nB, nN, T, scene, sol);
        return;
    end

    %% ============ ★ 关键修复3：alpha 裁剪到 [0,1] ============
    % 求解器的数值残值可能让 alpha 略微超出 [0,1]，例如 -1e-9 或 1.0001。
    % 直接使用会导致 ENS 出现负值。这里强制裁剪。
    res.alpha = max(0, min(1, res.alpha));
    res.y     = max(0, min(1, res.y));
    res.s     = max(0, min(1, res.s));
    res.d     = max(0, min(1, res.d));

    %% -------- 汇总 ENS 与经济损失 --------
        %% -------- 汇总 ENS 与经济损失（★ 分类别） --------
    dcIdx  = find(strcmp(sys.nodeType,'数据中心'));
    hosIdx = find(strcmp(sys.nodeType,'医院'));

    ens = 0;  loss_USD = 0;
    ens_DC = 0;  ens_Hos = 0;  ens_Ind = 0;  ens_Res = 0;

    for t = 1:T
        for j = 2:nN
            MWh_j = Pload(j) * baseMVA * res.alpha(j,t) * cfg.dt;
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

    if ens < -1e-6
        fprintf('    [!] ENS 为负 (%.4e)，视为失败\n', ens);
        res = make_failed_result(nB, nN, T, scene, sol);
        return;
    end

    res.ENS       = max(0, ens);
    res.ENS_w     = max(0, loss_USD);
    res.ENS_DC    = max(0, ens_DC);
    res.ENS_Hos   = max(0, ens_Hos);
    res.ENS_Ind   = max(0, ens_Ind);
    res.ENS_Res   = max(0, ens_Res);
    res.ENS_crit  = max(0, ens_DC + ens_Hos);   % 关键负荷汇总
    res.obj       = value(obj);
    res.success   = true;
end

%% ============ 局部函数：构造失败结果 ============
function res = make_failed_result(nB, nN, T, scene, sol)
% 所有数值字段设为 NaN，字段名与成功结果完全一致
    res.alpha   = nan(nN, T);
    res.y       = nan(nB, T);
    res.s       = nan(nB, T);
    res.d       = nan(nB, T);
    res.sol     = sol;
    res.scene   = scene;
    res.ENS     = NaN;
    res.ENS_w   = NaN;
    res.obj     = NaN;
    res.success = false;
end