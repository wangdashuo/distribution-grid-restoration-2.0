%% ============ 主计算：训练 + 5 场景对比 ============
clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

cfg = config();
sys = ieee69bus();
rng(cfg.seed);

%% 阶段1: AI 训练数据
fprintf('\n===== 阶段1: 生成 AI 训练数据 =====\n');
[X, Y] = generate_training_data(sys, cfg);

%% 阶段2: 训练
fprintf('\n===== 阶段2: 训练抢修优先级模型 =====\n');
model = train_priority_model(X, Y);

%% 阶段3: 测试故障
fprintf('\n===== 阶段3: 生成测试场景 =====\n');
testFault = generate_fault_scenario(sys, cfg);
fprintf('  故障线路: %s\n', mat2str(find(testFault)'));

wAI = predict_priority(model, testFault, sys, cfg);
for e = find(testFault)'
    fprintf('    线路 %2d: w = %.3f\n', e, wAI(e));
end

%% 阶段4: 5 场景对比（含 AI 快速决策）
fprintf('\n===== 阶段4: 5 场景对比（含 AI 加速）=====\n');

scenes = {
    'S1: 统一价 · 无重要度 · 无AI',  false, false, false, 'milp';
    'S2: 分档价 · 有重要度 · 无AI',  false, true,  false, 'milp';
    'S3: 分档价 · 有可靠性 · 无AI',  true,  true,  false, 'milp';
    'S4: 分档价 · 有可靠性 · +AI',   true,  true,  true,  'milp';
    'S5: AI-only 快速决策',           true,  true,  false, 'fast';
};

results = struct([]);
nFailMain = 0;
for k = 1:size(scenes,1)
    fprintf('\n  [%d/5] %s ...\n', k, scenes{k,1});
    sc.useReliability = scenes{k,2};
    sc.useImportance  = scenes{k,3};
    sc.useAI          = scenes{k,4};

    t1 = tic;
    if strcmp(scenes{k,5}, 'milp')
        r = solve_restoration(testFault, wAI, sys, cfg, sc);
    else
        r = solve_restoration_fast(testFault, wAI, sys, cfg);
    end
    r.runtime = toc(t1);
    r.name = scenes{k,1};
    r.wAI  = wAI;
    if ~isfield(r,'scene'), r.scene = sc; end

    % 求解失败处理
    if ~r.success
        nFailMain = nFailMain + 1;
        fprintf('    [!] 求解失败，标记为空结果\n');
        fprintf('    用时 %.4f 秒 | ENS=NaN | 损失=NaN\n', r.runtime);
    else
        fprintf('    用时 %.4f 秒 | ENS=%.4f MWh | 损失=%.1f $\n', ...
                r.runtime, r.ENS, r.ENS_w);
    end

    % ===== 字段统一（防御性编程）=====
    if k > 1
        f1 = sort(fieldnames(results));
        f2 = sort(fieldnames(r));
        if ~isequal(f1, f2)
            fprintf('  [警告] 场景%d 字段不一致，自动补齐\n', k);
            for ii = 1:numel(f1)
                if ~isfield(r, f1{ii}), r.(f1{ii}) = []; end
            end
            for ii = 1:numel(f2)
                if ~isfield(results, f2{ii})
                    for kk = 1:numel(results)
                        results(kk).(f2{ii}) = []; %#ok<SAGROW>
                    end
                end
            end
            r = orderfields(r, results);
        end
    end

    if k == 1
        results = r;
    else
        results(k) = r; %#ok<SAGROW>
    end
end

%% 汇总
fprintf('\n========= 结果汇总 =========\n');
fprintf('%-38s %11s %14s %14s %8s\n', ...
        '场景', '用时(s)', 'ENS(MWh)', '损失($)', 'success');
for k = 1:numel(results)
    if results(k).success
        fprintf('%-38s %11.4f %14.4f %14.1f %8s\n', results(k).name, ...
                results(k).runtime, results(k).ENS, results(k).ENS_w, '✓');
    else
        fprintf('%-38s %11.4f %14s %14s %8s\n', results(k).name, ...
                results(k).runtime, 'NaN', 'NaN', '✗');
    end
end

%% 失败场景提醒
if nFailMain > 0
    fprintf('\n[警告] 有 %d 个场景求解失败，结果不可用\n', nFailMain);
    fprintf('建议：\n');
    fprintf('  1) 把 cfg.T 从 4 降到 3，减小 MILP 规模\n');
    fprintf('  2) 把 cfg.maxFaults 从 4 降到 3，减少故障数\n');
    fprintf('  3) 把 cfg.Vmin 从 0.94 放宽到 0.90\n');
    fprintf('  4) 换用 gurobi / cplex 求解器\n');
end

%% AI 加速比（只在所有场景都成功时才计算）
succ = [results.success];
if numel(results) >= 5 && all(succ)
    fprintf('\n========= AI 加速效果 =========\n');
    mean_milp = mean([results(1:4).runtime]);
    fprintf('  MILP 平均:   %.4f 秒\n', mean_milp);
    fprintf('  AI-fast:     %.4f 秒\n', results(5).runtime);
    fprintf('  加速比:      %.0f 倍\n', ...
        mean_milp / max(results(5).runtime, 1e-6));
    if results(4).ENS > 0
        fprintf('  AI vs S4 损失: %.2f%%\n', ...
            (results(5).ENS_w - results(4).ENS_w) / results(4).ENS_w * 100);
    end
else
    fprintf('\n[提示] 有场景求解失败，跳过 AI 加速比计算\n');
    failedIdx = find(~succ);
    fprintf('  失败场景: %s\n', mat2str(failedIdx));
end

save('results.mat', 'results', 'sys', 'cfg', 'testFault', 'wAI', 'model');
fprintf('\n[已保存] results.mat\n');
fprintf('运行 presentation/run_presentation 生成全部图表。\n');