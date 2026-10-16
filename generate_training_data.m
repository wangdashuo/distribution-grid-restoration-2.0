function [X, Y] = generate_training_data(sys, cfg)
% 生成 AI 训练数据：MILP 求解多故障场景 → 从最优解提取优先级标签
% ★ 使用 parfor 并行求解

    t0 = tic;
    [paths, downstream] = build_topology(sys);
    nB = sys.nBranch;

    sc = struct('useReliability', true, ...
                'useImportance',  true, ...
                'useAI',          false);

    % ---- 生成所有故障场景 ----
    faults = cell(cfg.nScenarios, 1);
    for it = 1:cfg.nScenarios
        faults{it} = generate_fault_scenario(sys, cfg);
    end

    % ---- 检查并行池 ----
    pool = gcp('nocreate');
    if isempty(pool)
        fprintf('  [并行] 未检测到并行池，改用串行\n');
        useParallel = false;
    else
        fprintf('  [并行] 使用 %d 个 worker\n', pool.NumWorkers);
        useParallel = true;
    end

    % ---- 求解所有场景 ----
    fprintf('  [AI数据·MILP] 求解 %d 个场景%s ...\n', ...
            cfg.nScenarios, ternary(useParallel, '（并行）', '（串行）'));

    sols     = cell(cfg.nScenarios, 1);
    runtimes = zeros(cfg.nScenarios, 1);

    if useParallel
        % ---------- parfor 版本 ----------
        zeroW = zeros(nB, 1);
        parfor it = 1:cfg.nScenarios
            t1 = tic;
            sols{it} = solve_restoration(faults{it}, zeroW, sys, cfg, sc);
            runtimes(it) = toc(t1);
        end
    else
        % ---------- 串行版本（无并行池时回退）----------
        for it = 1:cfg.nScenarios
            t1 = tic;
            sols{it} = solve_restoration(faults{it}, zeros(nB,1), sys, cfg, sc);
            runtimes(it) = toc(t1);
        end
    end

    % ---- 打印每个场景 ----
    nFail = 0;
    for it = 1:cfg.nScenarios
        if sols{it}.success
            fprintf('    场景 %2d/%d | ENS=%.4f MWh | 用时 %.2fs\n', ...
                    it, cfg.nScenarios, sols{it}.ENS, runtimes(it));
        else
            nFail = nFail + 1;
            fprintf('    场景 %2d/%d | [求解失败，跳过] | 用时 %.2fs\n', ...
                    it, cfg.nScenarios, runtimes(it));
        end
    end

    % ---- 提取训练样本 ----
    X = []; Y = [];
    nSkip = 0;
    for it = 1:cfg.nScenarios
        r = sols{it};
        if ~r.success, nSkip = nSkip + 1; continue; end
        if r.ENS < 1e-4, nSkip = nSkip + 1; continue; end

        fault = faults{it};
        for e = find(fault)'
            f = extract_features(e, sys, paths, downstream);
            tFix = find(r.s(e,:) > 0.5, 1);

            if isempty(tFix)
                ds = downstream{e};
                if isempty(ds) || sum(sys.Pload_kW(ds)) < 1
                    prio = 0;
                else
                    prio = 0.1;
                end
            else
                prio = (cfg.T - tFix + 1) / cfg.T;
            end
            X = [X; f]; Y = [Y; prio]; %#ok<AGROW>
        end
    end

    fprintf('  [AI数据] 有效样本=%d, 求解失败=%d, 跳过场景=%d, 用时=%.2fs\n', ...
            size(X,1), nFail, nSkip, toc(t0));

    if size(X,1) < 5
        warning('有效训练样本过少（%d），AI 模型可能不可靠', size(X,1));
    end
end

% ============ 局部函数 ============
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end